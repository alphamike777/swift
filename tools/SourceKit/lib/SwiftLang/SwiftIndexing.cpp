//===--- SwiftIndexing.cpp ------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "SwiftASTManager.h"
#include "SwiftLangSupport.h"
#include "SourceKit/Support/Logging.h"
#include "SourceKit/Support/Tracing.h"
#include "SourceKit/Support/UIdent.h"

#include "swift/Frontend/Frontend.h"
#include "swift/Frontend/PrintingDiagnosticConsumer.h"
#include "swift/Index/Index.h"
#include "swift/Serialization/SerializedModuleLoader.h"
// This is included only for createLazyResolver(). Move to different header ?
#include "swift/Sema/IDETypeChecking.h"
#include "llvm/Support/Path.h"

using namespace SourceKit;
using namespace swift;
using namespace swift::index;

static UIdent KindImportModuleClang("source.lang.swift.import.module.clang");
static UIdent KindImportModuleSwift("source.lang.swift.import.module.swift");

static UIdent getUIDForDependencyKind(bool isClangModule) {
  return isClangModule ? KindImportModuleClang : KindImportModuleSwift;
}

class SKIndexDataConsumer : public IndexDataConsumer {
public:
  SKIndexDataConsumer(IndexingConsumer &C) : impl(C) {}

private:
  void failed(StringRef error) override { impl.failed(error); }

  void warning(StringRef warning) override {
    LOG_WARN_FUNC(warning);
  }

  bool enableWarnings() override {
    return Logger::isLoggingEnabledForLevel(Logger::Level::Warning);
  }

  bool startDependency(StringRef name, StringRef path, bool isClangModule, bool isSystem) override {
    auto kindUID = getUIDForDependencyKind(isClangModule);
    return impl.startDependency(kindUID, name, path, isSystem);
  }

  bool finishDependency(bool isClangModule) override {
    return impl.finishDependency(getUIDForDependencyKind(isClangModule));
  }

  Action startSourceEntity(const IndexSymbol &symbol) override {
    if (symbol.symInfo.Kind == SymbolKind::Parameter)
      return Skip;

    // report any parent relations to this reference
    if (symbol.roles & (SymbolRoleSet)SymbolRole::RelationBaseOf) {
      withEntityInfo(symbol, [this](const EntityInfo &info) {
        return impl.recordRelatedEntity(info);
      });
    }

    // filter out references with invalid locations
    if (symbol.roles & (SymbolRoleSet)SymbolRole::Reference &&
        (symbol.line == 0 || symbol.column == 0))
      return Skip;


    // start the entity (ref or def)
    if (!withEntityInfo(symbol, [this](const EntityInfo &info) {
        return impl.startSourceEntity(info);
    })) return Abort;


    // report relations this occurrence has
    for (auto Relation: symbol.Relations) {
      if (Relation.roles & (SymbolRoleSet)SymbolRole::RelationOverrideOf) {
        if (!withEntityInfo(Relation, [this](const EntityInfo &info) {
          return impl.recordRelatedEntity(info);
        })) return Abort;
      }
    }
    return Continue;
  }

  bool finishSourceEntity(SymbolInfo symInfo, SymbolRoleSet roles) override {
    bool isRef = roles & (unsigned)SymbolRole::Reference;
    auto UID = SwiftLangSupport::getUIDForSymbol(symInfo, isRef);
    return impl.finishSourceEntity(UID);
  }

  std::vector<UIdent> getDeclAttributeUIDs(const Decl *decl) {
    std::vector<UIdent> uidAttrs =
      SwiftLangSupport::UIDsFromDeclAttributes(decl->getAttrs());

    // check if we should report an implicit @objc attribute
    if (!decl->getAttrs().getAttribute(DeclAttrKind::DAK_ObjC)) {
      if (auto *VD = dyn_cast<ValueDecl>(decl)) {
        if (VD->isObjC()) {
            uidAttrs.push_back(SwiftLangSupport::getUIDForObjCAttr());
        }
      }
    }
    return uidAttrs;
  }

  template <typename F>
  bool withEntityInfo(const IndexSymbol &symbol, F func) {
    EntityInfo info;
    bool isRef = symbol.roles & (unsigned)SymbolRole::Reference;
    bool isImplicit = symbol.roles & (unsigned)SymbolRole::Implicit;

    info.Kind = SwiftLangSupport::getUIDForSymbol(symbol.symInfo, isRef);
    info.Name = isImplicit? "" : symbol.name;
    info.USR = symbol.USR;
    info.Group = symbol.group;
    info.Line = symbol.line;
    info.Column = symbol.column;
    info.ReceiverUSR = symbol.getReceiverUSR();
    info.IsDynamic = symbol.roles & (unsigned)SymbolRole::Dynamic;
    info.IsImplicit = symbol.roles & (unsigned)SymbolRole::Implicit;
    info.IsTestCandidate = symbol.symInfo.Properties & SymbolProperty::UnitTest;
    std::vector<UIdent> uidAttrs;
    if (!isRef) {
      uidAttrs = getDeclAttributeUIDs(symbol.decl);
      info.Attrs = uidAttrs;
    }
    return func(info);
  }

  template <typename F>
  bool withEntityInfo(const IndexRelation &relation, F func) {
    EntityInfo info;
    bool isRef = (relation.roles & (unsigned)SymbolRole::Reference) ||
      (relation.roles & (unsigned)SymbolRole::RelationOverrideOf);
    info.Kind = SwiftLangSupport::getUIDForSymbol(relation.symInfo, isRef);
    info.Name = relation.name;
    info.USR = relation.USR;
    info.Group = relation.group;
    info.IsDynamic = relation.roles & (unsigned)SymbolRole::Dynamic;
    info.IsTestCandidate = relation.symInfo.Properties & SymbolProperty::UnitTest;
    std::vector<UIdent> uidAttrs;
    if (!isRef) {
      uidAttrs = getDeclAttributeUIDs(relation.decl);
      info.Attrs = uidAttrs;
    }
    return func(info);
  }

private:
  IndexingConsumer &impl;
};

static void indexModule(llvm::MemoryBuffer *Input,
                        StringRef ModuleName,
                        IndexingConsumer &IdxConsumer,
                        CompilerInstance &CI,
                        ArrayRef<const char *> Args) {
  ASTContext &Ctx = CI.getASTContext();
  std::unique_ptr<SerializedModuleLoader> Loader;
  ModuleDecl *Mod = nullptr;
  if (ModuleName == Ctx.StdlibModuleName.str()) {
    Mod = Ctx.getModule({ {Ctx.StdlibModuleName, SourceLoc()} });
  } else {
    Loader = SerializedModuleLoader::create(Ctx);
    auto Buf = std::unique_ptr<llvm::MemoryBuffer>(
        llvm::MemoryBuffer::getMemBuffer(Input->getBuffer(),
                                         Input->getBufferIdentifier()));

    // FIXME: These APIs allocate memory on the ASTContext, meaning it may not
    // be freed for a long time.
    Mod = ModuleDecl::create(Ctx.getIdentifier(ModuleName), Ctx);
    // Indexing is not using documentation now, so don't open the module
    // documentation file.
    // FIXME: refactor the frontend to provide an easy way to figure out the
    // correct filename here.
    auto FUnit = Loader->loadAST(*Mod, None, std::move(Buf), nullptr, nullptr,
                                 /*isFramework*/false,
                                 /*treatAsPartialModule*/false);

    // FIXME: Not knowing what went wrong is pretty bad. loadModule() should be
    // more modular, rather than emitting diagnostics itself.
    if (!FUnit) {
      IdxConsumer.failed("failed to load module");
      return;
    }

    Mod->setHasResolvedImports();
  }

  // Setup a typechecker for protocol conformance resolving.
  (void)createTypeChecker(Ctx);

  SKIndexDataConsumer IdxDataConsumer(IdxConsumer);
  index::indexModule(Mod, IdxDataConsumer);
}


//===----------------------------------------------------------------------===//
// IndexSource
//===----------------------------------------------------------------------===//

template <typename Str>
static void initTraceInfoImpl(trace::SwiftInvocation &SwiftArgs,
                              StringRef InputFile,
                              ArrayRef<Str> Args) {
  llvm::raw_string_ostream OS(SwiftArgs.Args.Arguments);
  interleave(Args, [&OS](StringRef arg) { OS << arg; }, [&OS] { OS << ' '; });
  SwiftArgs.Args.PrimaryFile = InputFile;
}

void trace::initTraceInfo(trace::SwiftInvocation &SwiftArgs,
                          StringRef InputFile,
                          ArrayRef<const char *> Args) {
  initTraceInfoImpl(SwiftArgs, InputFile, Args);
}

void trace::initTraceInfo(trace::SwiftInvocation &SwiftArgs,
                          StringRef InputFile,
                          ArrayRef<std::string> Args) {
  initTraceInfoImpl(SwiftArgs, InputFile, Args);
}

void SwiftLangSupport::indexSource(StringRef InputFile,
                                   IndexingConsumer &IdxConsumer,
                                   ArrayRef<const char *> OrigArgs) {
  std::string Error;
  auto InputBuf = ASTMgr->getMemoryBuffer(InputFile, Error);
  if (!InputBuf) {
    IdxConsumer.failed(Error);
    return;
  }

  StringRef Filename = llvm::sys::path::filename(InputFile);
  StringRef FileExt = llvm::sys::path::extension(Filename);

  bool IsModuleIndexing = (FileExt == ".swiftmodule" || FileExt == ".pcm");
  CompilerInstance CI;
  // Display diagnostics to stderr.
  PrintingDiagnosticConsumer PrintDiags;
  CI.addDiagnosticConsumer(&PrintDiags);

  // Add -disable-typo-correction, since the errors won't be captured in the
  // response, and it can be expensive to do typo-correction when there are many
  // errors, which is common in indexing.
  SmallVector<const char *, 16> Args(OrigArgs.begin(), OrigArgs.end());
  Args.push_back("-Xfrontend");
  Args.push_back("-disable-typo-correction");

  CompilerInvocation Invocation;
  bool Failed = true;
  if (IsModuleIndexing) {
    Failed = getASTManager()->initCompilerInvocationNoInputs(
        Invocation, Args, CI.getDiags(), Error);
  } else {
    Failed = getASTManager()->initCompilerInvocation(
        Invocation, Args, CI.getDiags(), InputFile, Error);
  }
  if (Failed) {
    IdxConsumer.failed(Error);
    return;
  }

  if (IsModuleIndexing) {
    if (CI.setup(Invocation))
      return;
    // Indexing needs IDE requests
    registerIDERequestFunctions(CI.getASTContext().evaluator);
    bool IsClangModule = (FileExt == ".pcm");
    if (IsClangModule) {
      IdxConsumer.failed("Clang module files are not supported");
      return;
    }

    indexModule(InputBuf.get(), llvm::sys::path::stem(Filename),
                IdxConsumer, CI, Args);
    return;
  }

  if (!Invocation.getFrontendOptions().InputsAndOutputs.hasInputs()) {
    IdxConsumer.failed("no input filenames specified");
    return;
  }

  if (CI.setup(Invocation))
    return;
  // Indexing needs IDE requests
  registerIDERequestFunctions(CI.getASTContext().evaluator);
  trace::TracedOperation TracedOp(trace::OperationKind::IndexSource);
  if (TracedOp.enabled()) {
    trace::SwiftInvocation SwiftArgs;
    trace::initTraceInfo(SwiftArgs, InputFile, Args);
    TracedOp.start(SwiftArgs);
  }

  CI.performSema();

  // NOTE: performSema() may end up with some gruesome error preventing it from
  // setting primary file correctly
  if (!CI.getPrimarySourceFile()) {
    IdxConsumer.failed("no primary source file found");
    return;
  }

  // Setup a typechecker for protocol conformance resolving.
  (void)createTypeChecker(CI.getASTContext());

  SKIndexDataConsumer IdxDataConsumer(IdxConsumer);
  index::indexSourceFile(CI.getPrimarySourceFile(), IdxDataConsumer);
}
