import random
import math

def generate_task(difficulty: str) -> dict:

    if difficulty == "easy":
        return _generate_easy_task()
    elif difficulty == "medium":
        return _generate_medium_task()
    elif difficulty == "hard":
        return _generate_hard_task()
    else:
        return _generate_easy_task()

def _graph_points(function, start=-4, end=4):
    return [[x, round(function(x), 2)] for x in range(start, end + 1)]

def _generate_easy_task() -> dict:
    task_types = ["percentage", "simple_function", "graph_recognition"]
    task_type = random.choice(task_types)
    if task_type == "percentage":
        percentage = random.choice([10, 20, 25, 50, 75])
        base = random.choice([40, 60, 80, 100, 200])
        result = int(base * percentage / 100)
        wrong_answers = set()
        while len(wrong_answers) < 3:
            wrong = result + random.choice([-10, -5, 5, 10, -20, 20])
            if wrong > 0 and wrong != result:
                wrong_answers.add(wrong)
        options = [str(result)] + [str(w) for w in wrong_answers]
        random.shuffle(options)
        return {
            "task_type": task_type,
            "question": f"Wie viel sind {percentage}% von {base}?",
            "correct_answer": str(result),
            "options": options,
            "graph_type": None
        }
    elif task_type == "simple_function":
        a = random.randint(1, 5)
        b = random.randint(0, 10)
        x = random.randint(1, 5)
        result = a * x + b
        wrong_answers = set()
        while len(wrong_answers) < 3:
            wrong = result + random.choice([-3, -2, -1, 1, 2, 3])
            if wrong != result:
                wrong_answers.add(wrong) 
        options = [str(result)] + [str(w) for w in wrong_answers]
        random.shuffle(options)
        return {
            "task_type": task_type,
            "question": f"f(x) = {a}x + {b}\nBerechne f({x})",
            "correct_answer": str(result),
            "options": options,
            "graph_type": None
        }
    else:
        graph_types = [
            ("linear", "Gerade"),
            ("parabola", "Parabel"),
            ("hyperbola", "Hyperbel"),
            ("sine", "Sinuskurve"),
        ]
        correct = random.choice(graph_types)
        wrong = random.sample([g for g in graph_types if g != correct], 3)
        options = [correct[1]] + [w[1] for w in wrong]
        random.shuffle(options)
        return {
            "task_type": task_type,
            "question": "Welchen Funktionstyp zeigt dieser Graph?",
            "correct_answer": correct[1],
            "options": options,
            "graph_type": correct[0]
        }
    
def _generate_medium_task() -> dict:
    task_types = ["power_root", "quadratic", "intersection"]
    task_type = random.choice(task_types)
    if task_type == "power_root":
        sub_type = random.choice(["power", "root"])
        if sub_type == "power":
            base = random.randint(2, 5)
            exp = random.randint(2, 4)
            result = base ** exp
            wrong_answers = set()
            while len(wrong_answers) < 3:
                wrong = result + random.choice([-20, -10, -5, 5, 10, 20, 50])
                if wrong > 0 and wrong != result:
                    wrong_answers.add(wrong)
            options = [str(result)] + [str(w) for w in wrong_answers]
            random.shuffle(options)
            return {
                "task_type": task_type,
                "question": f"Berechne: {base}^{exp}",
                "correct_answer": str(result),
                "options": options,
                "graph_type": None
            }
        else:
            result = random.randint(2, 12)
            radicand = result ** 2
            wrong_answers = set()
            while len(wrong_answers) < 3:
                wrong = result + random.choice([-2, -1, 1, 2, 3])
                if wrong > 0 and wrong != result:
                    wrong_answers.add(wrong) 
            options = [str(result)] + [str(w) for w in wrong_answers]
            random.shuffle(options)
            return {
                "task_type": task_type,
                "question": f"Berechne: √{radicand}",
                "correct_answer": str(result),
                "options": options,
                "graph_type": None
            }
    elif task_type == "quadratic":
        a = random.choice([1, 2])
        b = random.randint(-3, 3)
        c = random.randint(-5, 5)
        x = random.randint(-3, 3)
        result = a * x**2 + b * x + c
        wrong_answers = set()
        while len(wrong_answers) < 3:
            wrong = result + random.choice([-5, -3, -2, -1, 1, 2, 3, 5])
            if wrong != result:
                wrong_answers.add(wrong)
        options = [str(result)] + [str(w) for w in wrong_answers]
        random.shuffle(options)
        formula = f"f(x) = {a}x²"
        if b != 0:
            formula += f" {'+' if b > 0 else '-'} {abs(b)}x"
        if c != 0:
            formula += f" {'+' if c > 0 else '-'} {abs(c)}"
        return {
            "task_type": task_type,
            "question": f"{formula}\nBerechne f({x})",
            "correct_answer": str(result),
            "options": options,
            "graph_type": "points",
            "graph_points": _graph_points(lambda value: a * value**2 + b * value + c),
        }
    else:
        a = random.randint(1, 3)
        b = random.randint(-5, 5)
        c = random.randint(-3, -1)
        d = random.randint(0, 10)
        x_val = (d - b) / (a - c)
        y_val = a * x_val + b 
        x_str = f"{x_val:.1f}" if x_val != int(x_val) else str(int(x_val))
        y_str = f"{y_val:.1f}" if y_val != int(y_val) else str(int(y_val))
        correct = f"({x_str} | {y_str})"
        wrong_answers = set()
        while len(wrong_answers) < 3:
            wx = x_val + random.choice([-2, -1, 1, 2])
            wy = y_val + random.choice([-2, -1, 1, 2])
            wx_str = f"{wx:.1f}" if wx != int(wx) else str(int(wx))
            wy_str = f"{wy:.1f}" if wy != int(wy) else str(int(wy))
            wrong = f"({wx_str} | {wy_str})"
            if wrong != correct:
                wrong_answers.add(wrong)
        options = [correct] + list(wrong_answers)
        random.shuffle(options)
        return {
            "task_type": task_type,
            "question": f"f(x) = {a}x + {b}\ng(x) = {c}x + {d}\nBerechne den Schnittpunkt.",
            "correct_answer": correct,
            "options": options,
            "graph_type": "lines",
            "graph_lines": [
                _graph_points(lambda value: a * value + b),
                _graph_points(lambda value: c * value + d),
            ]
        }
    
def _generate_hard_task() -> dict:
    task_types = ["polynomial", "exponential", "trigonometry", "binomial"]
    task_type = random.choice(task_types)
    if task_type == "polynomial":
        a = random.randint(1, 2)
        b = random.randint(-3, 3)
        c = random.randint(-5, 5)
        d = random.randint(-10, 10)
        x = random.randint(-2, 2)
        result = a * x**3 + b * x**2 + c * x + d
        wrong_answers = set()
        while len(wrong_answers) < 3:
            wrong = result + random.choice([-10, -5, -3, -2, -1, 1, 2, 3, 5, 10])
            if wrong != result:
                wrong_answers.add(wrong)
        options = [str(result)] + [str(w) for w in wrong_answers]
        random.shuffle(options)
        formula = f"f(x) = {a}x³"
        if b != 0:
            formula += f" {'+' if b > 0 else '-'} {abs(b)}x²"
        if c != 0:
            formula += f" {'+' if c > 0 else '-'} {abs(c)}x"
        if d != 0:
            formula += f" {'+' if d > 0 else '-'} {abs(d)}"
        return {
            "task_type": task_type,
            "question": f"{formula}\nBerechne f({x})",
            "correct_answer": str(result),
            "options": options,
            "graph_type": "points",
            "graph_points": _graph_points(lambda value: a * value**3 + b * value**2 + c * value + d),
        }
    elif task_type == "exponential":
        a = random.choice([1, 2, -1])
        x = random.choice([0, 1])
        result = math.exp(a * x)
        result_str = f"{result:.2f}" 
        wrong_answers = set()
        while len(wrong_answers) < 3:
            wrong = result + random.choice([-0.5, -0.3, 0.3, 0.5, 1.0])
            if wrong > 0 and abs(wrong - result) > 0.01:
                wrong_answers.add(f"{wrong:.2f}") 
        options = [result_str] + list(wrong_answers)
        random.shuffle(options)
        return {
            "task_type": task_type,
            "question": f"f(x) = e^({a}x)\nBerechne f({x})",
            "correct_answer": result_str,
            "options": options,
            "graph_type": "exponential"
        }
    elif task_type == "trigonometry":
        func = random.choice(["sin", "cos", "tan"])
        angle = random.choice([0, 30, 45, 60, 90, 180])
        if func == "sin":
            result = math.sin(math.radians(angle))
        elif func == "cos":
            result = math.cos(math.radians(angle))
        else:
            if angle == 90:
                angle = 45
            result = math.tan(math.radians(angle))
        result_str = f"{result:.2f}"
        wrong_answers = set()
        while len(wrong_answers) < 3:
            wrong = result + random.choice([-0.3, -0.2, -0.1, 0.1, 0.2, 0.3])
            if abs(wrong - result) > 0.01:
                wrong_answers.add(f"{wrong:.2f}")
        options = [result_str] + list(wrong_answers)
        random.shuffle(options)
        return {
            "task_type": task_type,
            "question": f"Berechne: {func}({angle}°)",
            "correct_answer": result_str,
            "options": options,
            "graph_type": None
        }
    else:
        n = random.choice([4, 5, 6])
        p = random.choice([0.25, 0.5, 0.75])
        k = random.randint(0, n)
        binom_coeff = math.comb(n, k)
        result = binom_coeff * (p ** k) * ((1 - p) ** (n - k))
        result_str = f"{result:.3f}"
        wrong_answers = set()
        while len(wrong_answers) < 3:
            wrong = result + random.choice([-0.1, -0.05, 0.05, 0.1, 0.15])
            if wrong > 0 and abs(wrong - result) > 0.001:
                wrong_answers.add(f"{wrong:.3f}") 
        options = [result_str] + list(wrong_answers)
        random.shuffle(options)
        return {
            "task_type": task_type,
            "question": f"Binomialverteilung:\nn = {n}, p = {p}\nBerechne P(X = {k})",
            "correct_answer": result_str,
            "options": options,
            "graph_type": None
        }