void main() {
  print("Hello");
  final date = foo();
  print("date " + date.toString());
}

DateTime foo() {
  return DateTime.now();
}
