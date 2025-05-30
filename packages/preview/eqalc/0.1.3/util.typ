/// Converts a label to a math expression.
/// -> content
#let label-to-math(
  /// A label representing a math expression.
  /// -> label
  label,
) = {
  query(label).first()
}

/// Split an equation into its left and right sides.
/// -> (content, content)
#let split-equation(
  /// The equation to split.
  /// -> content | label
  eq,
) = {
  if repr(type(eq)) == "label" {
    eq = label-to-math(eq)
  }

  let (body, ..fields) = eq.fields()
  let split-parts = (body + []).children.split[#sym.eq]
  let (l, r) = if split-parts.len() == 2 {
    split-parts
  } else {
    ($$.fields().body.children, split-parts.at(0))
  }
  fields = (fields.pairs().filter(p => p.first() != "label").to-dict())

  let l = math.equation(l.join(), ..fields, block: false)
  let r = math.equation(r.join(), ..fields, block: false)

  (l, r)
}



/// Converts math equations to strings.
/// -> string
#let math-to-str(
  /// The math expression.
  /// -> content | label
  eq,
  /// Get the part before the equals sign. This is used to get the function name.
  /// -> boolean
  get-first-part: false,
  /// The depth of the recursion. Don't manually set this.
  /// -> integer
  depth: 0,
) = {
  let map-math(n) = {
    // Operators like sin, cos, etc.
    if n.func() == math.op {
      "calc." + n.fields().text.text
      // Parentheses
    } else if n.func() == math.lr {
      math-to-str(n.body, depth: depth + 1)
      // Powers
    } else if n.has("base") and n.has("t") {
      (
        "calc.pow("
          + math-to-str(n.base, depth: depth + 1)
          + ", "
          + math-to-str(n.t, depth: depth + 1)
          + ")"
      )
      // Roots
    } else if n.func() == math.root {
      (
        "calc.root("
          + math-to-str(n.radicand, depth: depth + 1)
          + ", "
          + n.at("index", default: "2")
          + ")"
      )
      // Fractions
    } else if n.func() == math.frac {
      (
        "("
          + math-to-str(n.num, depth: depth + 1)
          + ")/("
          + math-to-str(n.denom, depth: depth + 1)
          + ")"
      )
      // ignore h
    } else if n.func() == h { } else if repr(n.func()) == "styled" {
      math-to-str(n.child, depth: depth + 1)
      // Default case
    } else if n == [ ] { } else if n.has("text") {
      if n.text == "e" {
        "(calc.e)"
      } else if n.text == $pi$.body.text {
        "(calc.pi)"
      } else if n.text == $tau$.body.text {
        "(calc.tau)"
      } else {
        n.text
      }
      // This is still a sequence.
    } else {
      math-to-str(n, depth: depth + 1)
    }
  }

  if repr(type(eq)) == "label" {
    eq = label-to-math(eq)
  }


  if depth == 0 {
    let (l, r) = split-equation(eq)
    if get-first-part {
      eq = l
    } else {
      eq = r
    }
  }

  if (
    not (repr(type(eq)) == "string" or repr(type(eq)) == "str")
      and eq.has("body")
  ) {
    eq = eq.body
  }

  // Adding `[]` to make it a sequence if it isn't already.
  let string = (eq + []).fields().children.map(map-math).join()

  if string == none {
    return ""
  }

  string = string
    .replace(
      regex("(\d|\))\s*([a-zA-Z]\b|calc|\()"),
      ((captures,)) => captures.first() + "*" + captures.last(),
    )
    .replace(math.dot, "*")

  string
}

/// Gets the main variable from a math expression.
/// -> string
#let get-variable(
  /// The math expression.
  /// -> string
  math-str,
) = {
  let reg = regex("\b([A-Za-z--e])\b")
  let match = math-str.match(reg)
  if match != none {
    match.text
  } else {
    "x"
  }
}
