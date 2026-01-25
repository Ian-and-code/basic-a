import strutils, tables, sequtils

func isIdent(c: char): bool =
  (c >= 'a' and c <= 'z') or c == '_'

# Parse a line like "OP ARG1, ARG2, ..."
proc parseLine(o: string): tuple[op: string, argv: seq[string], argc: int] =
  let cleanLine = o.strip()
  let parts = cleanLine.split(" ", maxsplit=1)
  if parts.len < 2:
    return (parts[0], @[], 0)
  
  let op = parts[0]
  let rest = parts[1]
  let argv = rest.split(",").mapIt(it.strip())
  return (op, argv, argv.len)

# Cut everything after the last occurrence of a character
proc cutAfterLast(o: string, char: char; includeChar: bool = false): string =
  let idx = o.rfind(char)
  if idx == -1:
    return o
  return if includeChar: o[0..idx] else: o[0..idx-1]

proc execute*(code: string) =
  var linesToJump: seq[int] = @[]
  var vars = initTable[string, string]()
  var labels = initTable[string, int]()

  var lines = code.splitLines()
  var index = 0

  # Devuelve el índice de la línea correspondiente al label
  proc getLabelLine(name: string): int =
    linesToJump[labels[name]]

  while index < lines.len:
    let line = lines[index]
    let lineInfo = parseLine(line.cutAfterLast(';'))

    case lineInfo.op
    of "SET":
      vars[lineInfo.argv[0]] = lineInfo.argv[1]
    of "ADD":
      let a = vars[lineInfo.argv[0]].parseFloat()
      let b = vars[lineInfo.argv[1]].parseFloat()
      vars[lineInfo.argv[0]] = $(a + b)
    of "SUB":
      let a = vars[lineInfo.argv[0]].parseFloat()
      let b = vars[lineInfo.argv[1]].parseFloat()
      vars[lineInfo.argv[0]] = $(a - b)
    of "MUL":
      let a = vars[lineInfo.argv[0]].parseFloat()
      let b = vars[lineInfo.argv[1]].parseFloat()
      vars[lineInfo.argv[0]] = $(a * b)
    of "DIV":
      let a = vars[lineInfo.argv[0]].parseFloat()
      let b = vars[lineInfo.argv[1]].parseFloat()
      vars[lineInfo.argv[0]] = $(a / b)
    of "POW":
      let a = vars[lineInfo.argv[0]].parseFloat()
      let b = vars[lineInfo.argv[1]].parseFloat()
      vars[lineInfo.argv[0]] = $(a ** b)
    of "SQRT":
      let a = vars[lineInfo.argv[0]].parseFloat()
      vars[lineInfo.argv[0]] = $(a ** 0.5)
    of "PRINT":
      let v = if vars.hasKey(lineInfo.argv[0]): vars[lineInfo.argv[0]] else: lineInfo.argv[0]
      stdout.write(v, "\n")
    of "LABEL":
      labels[lineInfo.argv[0]] = lineInfo.argv[1].parseInt()
    of ".":
      linesToJump.add(index+1)
    of "JZ":
      if vars[lineInfo.argv[0]].parseFloat() == 0:
        index = getLabelLine(lineInfo.argv[1])
        continue
    of "JNZ":
      if vars[lineInfo.argv[0]].parseFloat() != 0:
        index = getLabelLine(lineInfo.argv[1])
        continue
    of "JE":
      if vars[lineInfo.argv[0]] == vars[lineInfo.argv[1]]:
        index = getLabelLine(lineInfo.argv[2])
        continue
    of "JNE":
      if vars[lineInfo.argv[0]] != vars[lineInfo.argv[1]]:
        index = getLabelLine(lineInfo.argv[2])
        continue
    of "JMP":
      index = getLabelLine(lineInfo.argv[0])
      continue

    # Avanzar al siguiente índice (maneja jumps apuntando al `.`)
    index += 1
