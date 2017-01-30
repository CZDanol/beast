<p align="center">
	<img src="./doc/logo_256w.png">
</p>

# Beast Programming Language

Beast is a new programming language mostly inspired by C++ and D.

This repository contains (everything is WIP):
* Sample transcompiler to C++
* Language reference
* Bachelor thesis text (Czech language)

Source file extension: .be

## Progress
* Compiler: No working prototype yet (transcompiles to C++, no working prototype)
* Std library: Nothing at all
* Language reference: Nothing much

## Notable language features
* Importable modules (no header files like in C++)
* C++ style multiple inheritance class system
* Powerful compile-time engine
* Compiled to binary (to C++ so far)
* Const-by-default
* Compile-time language reflection

## Sample code
Please note that this code describes what the language should be able to do when done, not what it can do now.
```beast
class C {
  
@public:
  Int! x; // Int! == mutable Int
  
@public:
  Int #operator( Operator.binaryPlus, Int other ) { // Operator overloading, constant-value parameters
    return x + other;
  }
  
}

enum Enum {
  a, b, c
}

String foo( Enum e, @ctime Type T ) { // T is a 'template' parameter
  // 'template' and normal parameters are in the same parenthesis
  return e.to( String ) + T.#identifier; 
}

Void main() {
  @ctime Type T! = Int; // Type variables!
  T x = 3;
  
  T = C;
  T!? c := new C; // C!? - reference to a mutable object, := reference assignment operator
  c.x = 5;

  // Compile-time function execution, :XXX accessor that looks in parameter type
  @ctime String s = foo( :a, Int );
  stdout.writeln( s );
  
  stdout.writeln( c + x ); // Writes 8
  stdout.writeln( c.#operator.#parameters[1].type.#identifier ); // Compile-time language reflection
}
```
