from helper import greet_user, Calculator

def main():
    # Instead of input(), we use a fixed value for demonstration
    name = "Runner User"
    greet_user(name)

    calc = Calculator()
    print("5 + 3 =", calc.add(5, 3))
    print("10 - 7 =", calc.subtract(10, 7))
    print("6 * 4 =", calc.multiply(6, 4))
    print("8 / 2 =", calc.divide(8, 2))

if __name__ == "__main__":
    main()
