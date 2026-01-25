# execute.nim
import strutils, tables, math, re
# Parsea una línea del tipo "OP ARG1, ARG2, ..."
proc parseLine(o: string): tuple[op: string, argv: seq[string], argc: int] =
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

proc isBlankOrSemicolon(s: string): bool =
  # Eliminamos espacios, tabs y saltos de línea
  let trimmed = s.strip()  
  # Si queda vacío o es solo ";", devolvemos true
  return trimmed.len == 0 or trimmed == ";"

# Cut everything after the last occurrence of a character
proc cutAfterLast(o: string, char: char; includeChar: bool = false): string =
  if isBlankOrSemicolon(o):
    return "NOP"
  let idx = o.rfind(char)
  if idx == -1: return o
  return if includeChar: o[0..idx] else: o[0..idx-1]


proc execute*(code: string) =
  var vars = initTable[string,string]()
  let lines = code.strip().splitLines()
  var index = 0

  proc get(o: string): string =
    try: return vars[o]
    except: return o

  while index < lines.len:

    if isBlankOrSemicolon(lines[index]):
      index += 1
      continue
    let li = parseLine(lines[index].strip().cutAfterLast(';'))

    case li.op
    of "SET":
      vars[li.argv[0]] = li.argv[1]
    of "ADD":
      vars[li.argv[0]] = $((get(li.argv[0]).parseFloat()) + (get(li.argv[1]).parseFloat()))
    of "SUB":
      vars[li.argv[0]] = $((get(li.argv[0]).parseFloat()) - (get(li.argv[1]).parseFloat()))
    of "MUL":
      vars[li.argv[0]] = $((get(li.argv[0]).parseFloat()) * (get(li.argv[1]).parseFloat()))
    of "DIV":
      vars[li.argv[0]] = $((get(li.argv[0]).parseFloat()) / (get(li.argv[1]).parseFloat()))
    of "POW":
      vars[li.argv[0]] = $(math.pow(get(li.argv[0]).parseFloat(), get(li.argv[1]).parseFloat()))
    of "SQRT":
      vars[li.argv[0]] = $(math.sqrt(get(li.argv[0]).parseFloat()))
    of "PRINT":
      var v: string = get(li.argv[0])
      stdout.write(v)
    of "PRINTLN":
      var v: string = get(li.argv[0])
      stdout.write(v, "\n")
    of "JMP":
      index = li.argv[0].parseInt()
      continue
    of "JZ":
      if get(li.argv[0]).parseFloat() == 0:
        index = li.argv[1].parseInt()
        continue
    of "JNZ":
      if get(li.argv[0]).parseFloat() != 0:
        index = li.argv[1].parseInt()
        continue
    of "JE":
      if get(li.argv[0]) == get(li.argv[1]):
        index = li.argv[2].parseInt()
        continue
    of "JNE":
      if get(li.argv[0]) != get(li.argv[1]):
        index = li.argv[2].parseInt()
        continue
    of "JLT":
      if get(li.argv[0]).parseFloat() < get(li.argv[1])parseFloat():
        index = li.argv[2].parseInt()
        continue
    of "JGT":
      if get(li.argv[0]).parseFloat() > get(li.argv[1]).parseFloat():
        index = li.argv[2].parseInt()
        continue
    of "END":
      break
    of "NOP":
      discard
    else:
      discard

    index += 1
