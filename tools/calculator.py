#!/usr/bin/env python3
import ast
import operator as op
import sys
from decimal import Decimal, getcontext

# High precision for large/complex arithmetic.
getcontext().prec = 100

_ALLOWED_BIN_OPS = {
    ast.Add: op.add,
    ast.Sub: op.sub,
    ast.Mult: op.mul,
    ast.Div: op.truediv,
    ast.FloorDiv: op.floordiv,
    ast.Mod: op.mod,
    ast.Pow: op.pow,
}

_ALLOWED_UNARY_OPS = {
    ast.UAdd: lambda x: x,
    ast.USub: lambda x: -x,
}


class EvalError(Exception):
    pass


def _to_decimal(value):
    if isinstance(value, Decimal):
        return value
    return Decimal(str(value))


def _eval(node):
    if isinstance(node, ast.Expression):
        return _eval(node.body)

    if isinstance(node, ast.Constant):
        if isinstance(node.value, (int, float)):
            return _to_decimal(node.value)
        raise EvalError("Only numeric constants are allowed")

    if isinstance(node, ast.BinOp):
        left = _eval(node.left)
        right = _eval(node.right)
        fn = _ALLOWED_BIN_OPS.get(type(node.op))
        if fn is None:
            raise EvalError("Operator not allowed")
        try:
            return fn(left, right)
        except Exception as e:
            raise EvalError(str(e)) from e

    if isinstance(node, ast.UnaryOp):
        val = _eval(node.operand)
        fn = _ALLOWED_UNARY_OPS.get(type(node.op))
        if fn is None:
            raise EvalError("Unary operator not allowed")
        return fn(val)

    raise EvalError("Unsupported expression")


def calculate(expr: str) -> str:
    try:
        parsed = ast.parse(expr, mode="eval")
    except SyntaxError as e:
        raise EvalError(f"Invalid expression: {e.msg}") from e

    value = _eval(parsed)
    # Normalize without scientific notation when feasible.
    text = format(value.normalize(), 'f') if isinstance(value, Decimal) else str(value)
    if '.' in text:
        text = text.rstrip('0').rstrip('.')
    return text or "0"


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: calculator.py <expression>", file=sys.stderr)
        return 2

    expr = sys.argv[1].strip()
    if not expr:
        print("expression must be non-empty", file=sys.stderr)
        return 2

    try:
        print(calculate(expr))
    except EvalError as e:
        print(f"calculator failed: {e}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
