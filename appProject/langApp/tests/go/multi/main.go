package main

import "fmt"

func main() {
    fmt.Println("Main starting...")
    sayHello()
    result := add(3, 4)
    fmt.Printf("Sum: %d\n", result)
}
