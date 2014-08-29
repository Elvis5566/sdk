// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library analyzer2dart.treeShaker;

import 'dart:collection';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';

import 'closed_world.dart';

class TreeShaker {
  List<Element> _queue = <Element>[];
  Set<Element> _alreadyEnqueued = new HashSet<Element>();
  ClosedWorld _world = new ClosedWorld();

  void add(Element e) {
    if (_alreadyEnqueued.add(e)) {
      _queue.add(e);
    }
  }

  ClosedWorld shake(AnalysisContext context) {
    while (_queue.isNotEmpty) {
      Element e = _queue.removeLast();
      print('Tree shaker handling $e');
      CompilationUnit compilationUnit =
          context.getResolvedCompilationUnit(e.source, e.library);
      AstNode identifier =
          new NodeLocator.con1(e.nameOffset).searchWithin(compilationUnit);
      if (e is FunctionElement) {
        FunctionDeclaration declaration =
            identifier.getAncestor((node) => node is FunctionDeclaration);
        _world.elements[e] = declaration;
        declaration.accept(new TreeShakingVisitor(this));
      } else if (e is ClassElement) {
        ClassDeclaration declaration =
            identifier.getAncestor((node) => node is ClassDeclaration);
        _world.elements[e] = declaration;
        // TODO(paulberry): visit any members of the class that match active
        // selectors.
      }
    }
    print('Tree shaking done');
    return _world;
  }
}

class TreeShakingVisitor extends RecursiveAstVisitor {
  final TreeShaker treeShaker;

  TreeShakingVisitor(this.treeShaker);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    ConstructorElement staticElement = node.staticElement;
    if (staticElement != null) {
      // TODO(paulberry): Really we should enqueue the constructor, and then
      // when we visit it add the class to the class bucket.
      ClassElement classElement = staticElement.enclosingElement;
      treeShaker.add(classElement);
    } else {
      // TODO(paulberry): deal with this situation.  This can happen, for
      // example, in the case "main() => new Unresolved();" (which is a
      // warning, not an error).
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    Element staticElement = node.methodName.staticElement;
    if (staticElement != null) {
      // TODO(paulberry): deal with the case where staticElement is
      // not necessarily the exact target.  (Dart2js calls this a
      // "dynamic invocation").  We need a notion of "selector".  Maybe
      // we can use Dart2js selectors.
      treeShaker.add(staticElement);
    } else {
      // TODO(paulberry): deal with this case.
    }
    super.visitMethodInvocation(node);
  }
}
