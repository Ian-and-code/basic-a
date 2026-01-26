# execute.nim
import strutils, tables, math, re, os, times

const nan = 0.0 / 0.0

proc isIdent(s: string) =
  if s.len == 0:
    stderr.write("Error: identificador vacío\n")
    return
  for i, c in s:
    if not (('a' <= c and c <= 'z') or ('A' <= c and c <= 'Z') or c == '_' or (i != 0 and '0' <= c and c <= '9')):
      stderr.write("Error: identificador inválido: ", s, "\n")
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
  vars["debug"] = (value: "0", `type`: "NUMBER")
  let lines = code.strip().splitLines()
  var index = 0

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
      stderr.write("Error: label no encontrado: ", o, "\n")
      return -1

  while index < lines.len:
    if isBlankOrSemicolon(lines[index]):
      index += 1
      continue
    let li = parseLine(lines[index].strip().cutAfterLast(';'))
    case li.op
    of "COPYT":
      vars[li.argv[0]] = (value: li.argv[1].getV().getT(), `type`: "TYPE")
    of "COPYV":
      try:
        vars[li.argv[0]].value = li.argv[1].getV()
      except:
        vars[li.argv[0]] = (value: li.argv[1].getV(), `type`: vars[li.argv[1]].`type`)
    of "SETA":
      isIdent(li.argv[0])
      if vars.hasKey(li.argv[0]):
        vars[li.argv[0]].value = li.argv[1]   # solo asigna
      else:
        vars[li.argv[0]] = (value: li.argv[1], `type`: li.argv[1].getT())
    of "SET":
      if vars.hasKey(li.argv[0]):
        vars[li.argv[0]].value = li.argv[1]   # solo asigna
      else:
        stderr.write("Error: SET de variable no declarada: ", li.argv[0], "\n")
    of "SETL":
      isIdent(li.argv[0])
      labels[li.argv[0]] = li.argv[1].getI()
    of "SETN":
      isIdent(li.argv[0])
      vars[li.argv[0]] = (value: $(li.argv[1].getF()), `type`: "NUMBER")
    of "SETS":
      isIdent(li.argv[0])
      vars[li.argv[0]] = (value: li.argv[1], `type`: "STRING")
    of "SETB":
      isIdent(li.argv[0])
      vars[li.argv[0]] = (value: $(if li.argv[1].getB(): "TRUE" else: "FALSE"), `type`: "BOOL")
    of "RESET":
      if not vars.hasKey(li.argv[0]):
        stderr.write("Error: SET de variable no declarada: ", li.argv[0], "\n")
      else:
        vars[li.argv[0]] = (value: li.argv[1], `type`: li.argv[1].getT())
    # operaciones solo si tipos compatibles
    of "ADD":
      if getT(li.argv[0]) == "NUMBER" and getT(li.argv[1]) == "NUMBER":
        vars[li.argv[0]].value = $((li.argv[0].getF()) + (li.argv[1].getF()))
      else:
        stderr.write("Error: tipos incompatibles en ADD\n")
    of "SUB":
      if getT(li.argv[0]) == "NUMBER" and getT(li.argv[1]) == "NUMBER":
        vars[li.argv[0]].value = $((li.argv[0].getF()) - (li.argv[1].getF()))
      else:
        stderr.write("Error: tipos incompatibles en SUB\n")
    of "MUL":
      if getT(li.argv[0]) == "NUMBER" and getT(li.argv[1]) == "NUMBER":
        vars[li.argv[0]].value = $((li.argv[0].getF()) * (li.argv[1].getF()))
      else:
        stderr.write("Error: tipos incompatibles en MUL\n")
    of "DIV":
      if getT(li.argv[0]) == "NUMBER" and getT(li.argv[1]) == "NUMBER":
        vars[li.argv[0]].value = $((li.argv[0].getF()) / (li.argv[1].getF()))
      else:
        stderr.write("Error: tipos incompatibles en DIV\n")
    of "PRINT":
      stdout.write(li.argv[0].getV())
    of "PRINTLN":
      stdout.write(li.argv[0].getV(), "\n")
    of "JMP":
      index = getL(li.argv[0])
      continue
    of "JZ":
      if li.argv[0].getV().getT() != "NUMBER":
        stderr.write("Error: tipo incompatibles en JZ\n")
      elif li.argv[0].getV().getF() == 0:
        index = getL(li.argv[1])
        continue
    of "JNZ":
      if li.argv[0].getV().getT() != "NUMBER":
        stderr.write("Error: tipo incompatibles en JNZ\n")
      elif li.argv[0].getV().getF() != 0:
        index = getL(li.argv[1])
        continue
    of "JE":
      if li.argv[0].getV() == li.argv[1].getV():
        index = getL(li.argv[2])
        continue
    of "JNE":
      if li.argv[0].getV() != li.argv[1].getV():
        index = getL(li.argv[2])
        continue
    of "JLT":
      if li.argv[0].getV().getT() != "NUMBER" or li.argv[1].getV().getT() != "NUMBER":
        stderr.write("Error: tipos incompatibles en JLT\n")
      if li.argv[0].getV().getF() < li.argv[1].getV().getF():
        index = getL(li.argv[2])
        continue
    of "JGT":
      if li.argv[0].getV().getT() != "NUMBER" or li.argv[1].getV().getT() != "NUMBER":
        stderr.write("Error: tipos incompatibles en JGT\n")
      if li.argv[0].getV().getF() > li.argv[1].getV().getF():
        index = getL(li.argv[2])
        continue
    of ".":
      isIdent(li.argv[0])
      labels[li.argv[0]] = index
    of "END":
      return
    of "NOP":
      discard
    of "SLEEP":
      sleep(li.argv[0].getV().getI())
    else:
      if li.op.strip().isBlankOrSemicolon():
        index+=1
        continue
      stderr.write("operación " & li.op & " no es valida\n")

    index += 1

  if inFile:stderr.write("Error: operación end no ejecutada\n")
