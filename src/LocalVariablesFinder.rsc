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

private MethodVar createParameterMethodVar(bool isFinal, VariableDeclaratorId varId, UnannType varType) {
	name = trim(unparse(varId));
	varTypeStr = trim(unparse(varType));
	bool isParameter = true;
	bool isDeclaredWithinLoop = false;
	bool isEffectiveFinal = true;
	return methodVar(isFinal, name, varTypeStr, isParameter, isDeclaredWithinLoop, isEffectiveFinal);
}

// XXX ugly and not really DRY way of checking for vars within loop
private set[MethodVar] findVariablesInsideBody(MethodBody methodBody) {
	set[MethodVar] methodVars = {};
	set[str] nonEffectiveFinalOutsideLoopVars = {};
	set[str] varsWithinLoopNames = {};
	top-down visit(methodBody) {
	
		case EnhancedForStatement enhancedForStmt: {
			visit(enhancedForStmt) {	
				case (EnhancedForStatement) `for (<VariableModifier* varMod> <UnannType varType> <VariableDeclaratorId varId> : <Expression _> ) <Statement _>`:
					 methodVars += createLocalMethodVarWithinLoop(figureIfIsFinal(varMod), varId, varType);
				
				case (LocalVariableDeclaration) `<VariableModifier* varMod> <UnannType varType> <VariableDeclaratorList vdl>`: 
					visit(vdl) {
						case (VariableDeclaratorId) `<Identifier varId> <Dims? dims>`: {
								varsWithinLoopNames += unparse(varId);
								methodVars += createLocalMethodVarWithinLoop(figureIfIsFinal(varMod), varId, varType, dims);
							}
					}		
			}
		}
		
		
		
		case (LocalVariableDeclaration) `<VariableModifier* varMod> <UnannType varType> <VariableDeclaratorList vdl>`: {
			visit(vdl) {
				case (VariableDeclaratorId) `<Identifier varId> <Dims? dims>`: {
						if(unparse(varId) notin varsWithinLoopNames)
							methodVars += createLocalMethodVar(figureIfIsFinal(varMod), varId, varType, dims);
					}
			}
		}
		
		case (Assignment) `<LeftHandSide varName> <AssignmentOperator _> <Expression  _>`: nonEffectiveFinalOutsideLoopVars += "<varName>";
		
		case(CatchFormalParameter) `<VariableModifier* varMod> <CatchType varType> <VariableDeclaratorId varId>`:
			methodVars += createLocalMethodVar(figureIfIsFinal(varMod), varId, varType);	
		
	}
	
	
	return addNonEffectiveFinalVars(methodVars, nonEffectiveFinalOutsideLoopVars);
}

private MethodVar createLocalMethodVar(bool isFinal, VariableDeclaratorId varId, UnannType varType) {
	name = trim(unparse(varId));
	varTypeStr = trim(unparse(varType));
	bool isParameter = false;
	bool isDeclaredWithinLoop = false;
	bool isEffectiveFinal = true;
	return methodVar(isFinal, name, varTypeStr, isParameter, isDeclaredWithinLoop, isEffectiveFinal);
}

private MethodVar createLocalMethodVarWithinLoop(bool isFinal, VariableDeclaratorId varId, UnannType varType) {
	name = trim(unparse(varId));
	varTypeStr = trim(unparse(varType));
	bool isParameter = false;
	bool isDeclaredWithinLoop = true;
	bool isEffectiveFinal = true;
	return methodVar(isFinal, name, varTypeStr, isParameter, isDeclaredWithinLoop, isEffectiveFinal);
}

private MethodVar createLocalMethodVar(bool isFinal, Identifier varId, UnannType varType, Dims? dims) {
	name = trim(unparse(varId));
	varTypeStr = trim(unparse(varType));
	dimsStr = trim(unparse(dims));
	
	// Standarizing arrays to have varType ==  <UnannType varType>[] 
	if(dimsStr == "[]")
		varTypeStr += "[]";
	
	bool isParameter = false;
	bool isDeclaredWithinLoop = false;
	bool isEffectiveFinal = true;
	return methodVar(isFinal, name, varTypeStr, isParameter, isDeclaredWithinLoop, isEffectiveFinal);
}

private MethodVar createLocalMethodVarWithinLoop(bool isFinal, Identifier varId, UnannType varType, Dims? dims) {
	mv = createLocalMethodVar(isFinal, varId, varType, dims);
	mv.isDeclaredWithinLoop = true;
	return mv;
}

private MethodVar createLocalMethodVar(bool isFinal, VariableDeclaratorId varId, CatchType varType) {
	name = trim(unparse(varId));
	varTypeStr = trim(unparse(varType));
	bool isParameter = false;
	bool isDeclaredWithinLoop = false;
	bool isEffectiveFinal = true;
	return methodVar(isFinal, name, varTypeStr, isParameter, isDeclaredWithinLoop, isEffectiveFinal);
}

private bool figureIfIsFinal(VariableModifier* varMod) {
	if ("<varMod>" := "final")
		return true;
	return false;
}


// XXX ugly handling of non effective finals (mainly due to usage of sets)
private set[MethodVar] addNonEffectiveFinalVars(set[MethodVar] methodVars, set[str] nonEffectiveFinalOutsideLoopVars) {
	completeMethodVars = methodVars; 
	for (methodVar <- methodVars) {
		for (nonEffectiveFinalVar <- nonEffectiveFinalOutsideLoopVars) {
			if (methodVar.name == nonEffectiveFinalVar) {
				completeMethodVars -= methodVar;
				completeMethodVars += cloneMethodVarAsNonEffectiveFinal(methodVar);
			}
		}
	}
	return completeMethodVars;
}

private MethodVar cloneMethodVarAsNonEffectiveFinal(MethodVar m) {
	bool isEffectiveFinal = false;
	return methodVar(m.isFinal, m.name, m.varType, m.isParameter, m.isDeclaredWithinLoop, isEffectiveFinal);
}