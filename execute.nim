# execute.nim
import strutils, tables, math, re, os, times

const nan = 0.0 / 0.0

template writeError[T...](args: T...): return type =
  for i in args:
    stderr.write(i)
  stderr.write("\n")
  quit(1)

proc checkArgsLen(expected: int, realArgc: int, op: string) =
  if expected != realArgc:
    writeError("ArgumentNumberError: op ", op, " expected ", expected, " but recived ", realArgc)

proc isIdent(s: string) =
  if s.len == 0:
    writeError("Error: identificador vacío\n")
    return
  for i, c in s:
    if not (('a' <= c and c <= 'z') or ('A' <= c and c <= 'Z') or c == '_' or (i != 0 and '0' <= c and c <= '9')):
      writeError("Error: identificador inválido: ", s, "\n")
      break



func isInt(s: string): bool =
  try:
    discard parseInt(s)
    return true
  except ValueError:
    return false

# Parsea una línea del tipo "OP ARG1, ARG2, ..."
func parseLine(o: string): tuple[op: string, argv: seq[string], argc: int] =
  let cleanLine = o.strip()
  if cleanLine.len == 0:
    return ("", @[], 0)
  let parts = cleanLine.split(" ", maxsplit=1)
  if parts.len == 1:
    return (parts[0], @[], 0)
  let op = parts[0]

  # Transformamos los argumentos manualmente
  var argv: seq[string] = @[]
  for arg in parts[1].split(","):
    argv.add(arg.strip())

  return (op, argv, argv.len)

func isBlankOrSemicolon(s: string): bool =
  # Eliminamos espacios, tabs y saltos de línea
  let trimmed = s.strip()  
  # Si queda vacío o es solo ";", devolvemos true
  return trimmed.len == 0 or trimmed == ";"

# Cut everything after the last occurrence of a character
func cutAfterLast(o: string, char: char; includeChar: bool = false): string =
  if isBlankOrSemicolon(o):
    return "NOP"
  let idx = o.rfind(char)
  if idx == -1: return o
  return if includeChar: o[0..idx] else: o[0..idx-1]

proc execute*(code: string, inFile: bool = false) =
  var vars = initTable[string, tuple[value: string, `type`: string]]()
  var labels = initTable[string, int]()
  var funcs = initTable[string, int]()
  vars["%%n"] = (value: "\n", `type`: "STRING")
  vars["%%t"] = (value: "\t", `type`: "STRING")
  vars["%%b"] = (value: "\b", `type`: "STRING")
  vars["%%r"] = (value: "\r", `type`: "STRING")
  let lines = code.strip().splitLines()
  var index = 0
  var callStack: seq[int] = @[]
  # helpers
  func getV(o: string): string =
    if vars.hasKey(o):
      return vars[o].value
    else:
      return o

  func getF(o: string): float =
    if vars.hasKey(o):
      let v = vars[o]
      if v.`type` == "NUMBER": return v.value.parseFloat()
      elif v.`type` == "BOOL": return if v.value == "TRUE": 1.0 else: 0.0
      else: return nan
    if o == "TRUE": return 1.0
    elif o == "FALSE": return 0.0
    try: return o.parseFloat()
    except: return nan

  func getI(o: string): int = int(getF(o))
  func getB(o: string): bool = getF(o) != 0

  func getT(o: string): string =
    if vars.hasKey(o):
      return vars[o].`type`
    if o in @["TRUE","FALSE"]: return "BOOL"
    try:
      discard o.parseFloat()
      return "NUMBER"
    except:
      return "STRING"
  
  proc getL(o: string): int =
    if labels.hasKey(o):
      return labels[o]
    elif isInt(o):
      return o.getI()
    else:
      writeError("Error: label no encontrado: ", o, "\n")
      return -1

  while index  < lines.len:
    if isBlankOrSemicolon(lines[index]):
      index += 1
      continue
    let li = parseLine(lines[index].strip().cutAfterLast(';'))
    case li.op:
    of ".":
      isIdent(li.argv[0])
      labels[li.argv[0]] = index
    of ":":
      isIdent(li.argv[0])
      funcs[li.argv[0]] = index

    index += 1

  index = 0

  while index < lines.len:
    if isBlankOrSemicolon(lines[index]):
      index += 1
      continue
    let li = parseLine(lines[index].strip().cutAfterLast(';'))
    case li.op
    of "CALL":
      checkArgsLen(1, li.argc, "CALL")
      callStack.add(index+1)
      index = funcs[li.argv[0]]
    of "RETURN":
      checkArgsLen(0, li.argc, "RETURN")
      index = callStack.pop()
      continue
    of "COPYT":
      checkArgsLen(2, li.argc, "COPYT")
      vars[li.argv[0]] = (value: li.argv[1].getV().getT(), `type`: "TYPE")
    of "COPYV":
      checkArgsLen(2, li.argc, "COPYV")
      try:
        vars[li.argv[0]].value = li.argv[1].getV()
      except:
        vars[li.argv[0]] = (value: li.argv[1].getV(), `type`: vars[li.argv[1]].`type`)
    of "SETA":
      checkArgsLen(2, li.argc, "SETA")
      isIdent(li.argv[0])
      if vars.hasKey(li.argv[0]):
        vars[li.argv[0]].value = li.argv[1]   # solo asigna
      else:
        vars[li.argv[0]] = (value: li.argv[1], `type`: li.argv[1].getT())
    of "SET":
      checkArgsLen(2, li.argc, "SET")
      if vars.hasKey(li.argv[0]):
        vars[li.argv[0]].value = li.argv[1]   # solo asigna
      else:
        writeError("Error: SET de variable no declarada: ", li.argv[0], "\n")
    of "SETL":
      checkArgsLen(2, li.argc, "SETL")
      isIdent(li.argv[0])
      labels[li.argv[0]] = li.argv[1].getI()
    of "SETN":
      checkArgsLen(2, li.argc, "SETN")
      isIdent(li.argv[0])
      vars[li.argv[0]] = (value: $(li.argv[1].getF()), `type`: "NUMBER")
    of "SETS":
      checkArgsLen(2, li.argc, "SET")
      isIdent(li.argv[0])
      vars[li.argv[0]] = (value: li.argv[1], `type`: "STRING")
    of "SETB":
      checkArgsLen(2, li.argc, "SETB")
      isIdent(li.argv[0])
      vars[li.argv[0]] = (value: $(if li.argv[1].getB(): "TRUE" else: "FALSE"), `type`: "BOOL")
    of "RESET":
      checkArgsLen(2, li.argc, "RESET")
      if not vars.hasKey(li.argv[0]):
        writeError("Error: SET de variable no declarada: ", li.argv[0], "\n")
      else:
        vars[li.argv[0]] = (value: li.argv[1], `type`: li.argv[1].getT())
    # operaciones solo si tipos compatibles
    of "ADD":
      checkArgsLen(2, li.argc, "ADD")
      if getT(li.argv[0]) == "NUMBER" and getT(li.argv[1]) == "NUMBER":
        vars[li.argv[0]].value = $((li.argv[0].getF()) + (li.argv[1].getF()))
      else:
        writeError("Error: tipos incompatibles en ADD\n")
    of "SUB":
      checkArgsLen(2, li.argc, "SUB")
      if getT(li.argv[0]) == "NUMBER" and getT(li.argv[1]) == "NUMBER":
        vars[li.argv[0]].value = $((li.argv[0].getF()) - (li.argv[1].getF()))
      else:
        writeError("Error: tipos incompatibles en SUB\n")
    of "MUL":
      checkArgsLen(2, li.argc, "MUL")
      if getT(li.argv[0]) == "NUMBER" and getT(li.argv[1]) == "NUMBER":
        vars[li.argv[0]].value = $((li.argv[0].getF()) * (li.argv[1].getF()))
      else:
        writeError("Error: tipos incompatibles en MUL\n")
    of "DIV":
      checkArgsLen(2, li.argc, "DIV")
      if getT(li.argv[0]) == "NUMBER" and getT(li.argv[1]) == "NUMBER":
        vars[li.argv[0]].value = $((li.argv[0].getF()) / (li.argv[1].getF()))
      else:
        writeError("Error: tipos incompatibles en DIV\n")
    of "PRINT":
      var prints = ""
      for i, v in li.argv:
        prints &= v.getV()
      stdout.write(prints)
    of "PRINTLN":
      var prints = ""
      for i, v in li.argv:
        prints &= v.getV()
      stdout.write(prints, "\n")
    of "JMP":
      checkArgsLen(1, li.argc, "JMP")
      index = getL(li.argv[0])
      continue
    of "JZ":
      checkArgsLen(2, li.argc, "JZ")
      if li.argv[0].getV().getT() != "NUMBER":
        writeError("Error: tipo incompatibles en JZ\n")
      elif li.argv[0].getV().getF() == 0:
        index = getL(li.argv[1])
        continue
    of "JNZ":
      checkArgsLen(2, li.argc, "JNZ")
      if li.argv[0].getV().getT() != "NUMBER":
        writeError("Error: tipo incompatibles en JNZ\n")
      elif li.argv[0].getV().getF() != 0:
        index = getL(li.argv[1])
        continue
    of "JE":
      checkArgsLen(3, li.argc, "JE")
      if li.argv[0].getV() == li.argv[1].getV():
        index = getL(li.argv[2])
        continue
    of "JNE":
      checkArgsLen(3, li.argc, "JNE")
      if li.argv[0].getV() != li.argv[1].getV():
        index = getL(li.argv[2])
        continue
    of "JLT":
      checkArgsLen(3, li.argc, "JLT")
      if li.argv[0].getV().getT() != "NUMBER" or li.argv[1].getV().getT() != "NUMBER":
        writeError("Error: tipos incompatibles en JLT\n")
      if li.argv[0].getV().getF() < li.argv[1].getV().getF():
        index = getL(li.argv[2])
        continue
    of "JGT":
      checkArgsLen(3, li.argc, "JGT")
      if li.argv[0].getV().getT() != "NUMBER" or li.argv[1].getV().getT() != "NUMBER":
        writeError("Error: tipos incompatibles en JGT\n")
      if li.argv[0].getV().getF() > li.argv[1].getV().getF():
        index = getL(li.argv[2])
        continue
    of "END":
      checkArgsLen(0, li.argc, "END")
      return
    of "NOP":
      discard
    of "SLEEP":
      checkArgsLen(1, li.argc, "SLEEP")
      sleep(li.argv[0].getV().getI())
    else:
      if li.op.strip().isBlankOrSemicolon() or li.op == "." or li.op == ":":
        index+=1
        continue
      writeError("operación " & li.op & " no es valida\n")

    index += 1

  if inFile:writeError("Error: operación end no ejecutada\n")
