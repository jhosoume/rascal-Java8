module LocalVariablesFinder

import Set;
import lang::java::\syntax::Java18;
import String;
import ParseTree;
import IO;
import MethodVar;
import ParseTreeVisualization;

// syntax LocalVariableDeclarationStatement = LocalVariableDeclaration ";"+ ;
// syntax LocalVariableDeclaration = VariableModifier* UnannType VariableDeclaratorList ;
// syntax VariableDeclaratorList = variableDeclaratorList: {VariableDeclarator ","}+ ; 
// syntax VariableDeclarator = variableDeclarator: VariableDeclaratorId ("=" VariableInitializer)? ;

public set[MethodVar] findLocalVariables(MethodHeader methodHeader, MethodBody methodBody) {
	set[MethodVar] methodVars = {};
	methodVars += findVariablesAsParameters(methodHeader);
	methodVars += findVariablesInsideBody(methodBody);
	return methodVars;
}

private set[MethodVar] findVariablesAsParameters(MethodHeader methodHeader) {
	set[MethodVar] methodVars = {};
	visit(methodHeader) {
		case (FormalParameter) `<VariableModifier* varMod> <UnannType varType> <VariableDeclaratorId varId>`:
			methodVars += createParameterMethodVar(figureIfIsFinal(varMod), varId, varType);
	}
	return methodVars;
}

private set[MethodVar] findVariablesInsideBody(MethodBody methodBody) {
	set[MethodVar] methodVars = {};
	visit(methodBody) {
		
		case EnhancedForStatement enhancedForStmt: {
			visit(enhancedForStmt) {	
				case (EnhancedForStatement) `for (<VariableModifier* varMod> <UnannType varType> <VariableDeclaratorId varId> : <Expression _> ) <Statement _>`:
					 methodVars += createLocalMethodVarWithinLoop(figureIfIsFinal(varMod), varId, varType);
				
				// TODO maybe there is a better way besides checking this two times.
				case (LocalVariableDeclaration) `<VariableModifier* varMod> <UnannType varType> <VariableDeclaratorList vdl>`: 
					visit(vdl) {
						case (VariableDeclaratorId) `<Identifier varId> <Dims? dims>`:
							methodVars += createLocalMethodVarWithinLoop(figureIfIsFinal(varMod), varId, varType, dims);
					}		
			}
		}

		case (LocalVariableDeclaration) `<VariableModifier* varMod> <UnannType varType> <VariableDeclaratorList vdl>`: {
			visit(vdl) {
				case (VariableDeclaratorId) `<Identifier varId> <Dims? dims>`:
					methodVars += createLocalMethodVar(figureIfIsFinal(varMod), varId, varType, dims);
			}
		}
		
		case(CatchFormalParameter) `<VariableModifier* varMod> <CatchType varType> <VariableDeclaratorId varId>`:
			methodVars += createLocalMethodVar(figureIfIsFinal(varMod), varId, varType);	
		
	}
	return methodVars;
}

private MethodVar createParameterMethodVar(bool isFinal, VariableDeclaratorId varId, UnannType varType) {
	name = trim(unparse(varId));
	varTypeStr = trim(unparse(varType));
	return methodVar(isFinal, name, varTypeStr, true, false);
}

private MethodVar createLocalMethodVar(bool isFinal, VariableDeclaratorId varId, UnannType varType) {
	name = trim(unparse(varId));
	varTypeStr = trim(unparse(varType));
	return methodVar(isFinal, name, varTypeStr, false, false);
}

private MethodVar createLocalMethodVarWithinLoop(bool isFinal, VariableDeclaratorId varId, UnannType varType) {
	name = trim(unparse(varId));
	varTypeStr = trim(unparse(varType));
	return methodVar(isFinal, name, varTypeStr, false, true);
}

private MethodVar createLocalMethodVar(bool isFinal, Identifier varId, UnannType varType, Dims? dims) {
	name = trim(unparse(varId));
	varTypeStr = trim(unparse(varType));
	dimsStr = trim(unparse(dims));
	
	// Standarizing arrays to have varType ==  <UnannType varType>[] 
	if(dimsStr == "[]")
		varTypeStr += "[]";
		
	return methodVar(isFinal, name, varTypeStr, false, false);
}

private MethodVar createLocalMethodVarWithinLoop(bool isFinal, Identifier varId, UnannType varType, Dims? dims) {
	mv = createLocalMethodVar(isFinal, varId, varType, dims);
	mv.isDeclaredWithinLoop = true;
	return mv;
}

private MethodVar createLocalMethodVar(bool isFinal, VariableDeclaratorId varId, CatchType varType) {
	name = trim(unparse(varId));
	varTypeStr = trim(unparse(varType));
	return methodVar(isFinal, name, varTypeStr, false, false);
}

private bool figureIfIsFinal(VariableModifier* varMod) {
	if ("<varMod>" := "final")
		return true;
	return false;
}