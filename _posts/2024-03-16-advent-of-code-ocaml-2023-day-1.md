---
layout: post
title: Advent of Code 2023 in OCaml - Day 1
---

![OCaml logo](../img/posts/ocaml.png){: width="100%" }

A good way to learn a new programming language is to jump in and solve some practice exercises. At the end of each year Advent of Code release a new coding exercise each day until Christmas. It has become fairly popular over the years.

I have had an interest in the functional paradigm for a while, so this year I decided to complete the [Advent of Code 2023](https://adventofcode.com/2023) exercises in [OCaml](https://ocaml.org/). So, let's jump straight into the first day's exercise.

**Note:** I will be using Jane Street's [core](https://ocaml.org/p/core/latest) library as a replacement for OCaml's standard library.

## Part 1

### Problem Statement

There is a long-winded story about the Elves and a weather machine and so on, but let's just distill it down to a simple problem statement. Basically, we are given an input string that consists of lines of text. For each line of text, we should find the first and last digit in the line, combine them together, and parse them as an integer. We should then sum up all the integers.

Example input:

```
1abc2
pqr3stu8vwx
a1b2c3d4e5f
treb7uchet
```

Correct answer:

```
12 + 38 + 15 + 77 = 142
```

Note that the last line only contains a single digit. So, that single digit is the first and the last digit.

### Solution

To start with we will create a function to parse a digit character into an integer using its ASCII code. The `Char.to_int` function returns the ASCII code of a character:

```ocaml
let char_to_int digit =
  let zero = Char.to_int '0' in
  Char.to_int digit - zero
```

Let's now define a function that returns a tuple with the first and last digit character in a line:

```ocaml
let digits_from_line line =
  let left_char = String.find line ~f:Char.is_digit in
  let right_char = String.find (String.rev line) ~f:Char.is_digit in
  match (left_char, right_char) with
  | Some left_char, Some right_char -> (left_char, right_char)
  | _ -> raise (Failure "Couldn't find a digit in the string")
```

The `digits_from_line` function gets the first and last character digit: `left_char` and `right_char` respectively. A pattern match is used to check if either of these values are `None`. If either is `None` it raises a `Failure`.

We can now combine these two functions to calculate the integer value for each line:

```ocaml
let num_from_line line =
  let left_digit, right_digit = digits_from_line line in
  (char_to_int left_digit * 10) + char_to_int right_digit
```

At this point we can write a function that sums all the lines in a list of lines:

```ocaml
let sum_lines lines =
  let sum_nums acc line = acc + num_from_line line in
  List.fold lines ~init:0 ~f:sum_nums
```

The `List.fold` function takes an initial value which it then uses as an accumulator that's passed into the `f` function along with each line. The accumulator's new value for each line is the return value of the `f` function.

The last thing that remains is to actually read the input from a file and print the answer to stdout:

```ocaml
let () =
  let lines = In_channel.read_lines "inputs/day_01.txt" in
  let answer = sum_lines lines in
  Printf.printf "Answer for part 1: %d\n" answer
```

Putting this all together we end up with a `.ml` file like this:

```ocaml
open! Core

let char_to_int digit =
  let zero = Char.to_int '0' in
  Char.to_int digit - zero

let digits_from_line line =
  let left_char = String.find line ~f:Char.is_digit in
  let right_char = String.find (String.rev line) ~f:Char.is_digit in
  match (left_char, right_char) with
  | Some left_char, Some right_char -> (left_char, right_char)
  | _ -> raise (Failure "Couldn't find a digit in the string")

let num_from_line line =
  let left_digit, right_digit = digits_from_line line in
  (char_to_int left_digit * 10) + char_to_int right_digit

let sum_lines lines =
  let sum_nums acc line = acc + num_from_line line in
  List.fold lines ~init:0 ~f:sum_nums

let () =
  let lines = In_channel.read_lines "inputs/day_01.txt" in
  let answer = sum_lines lines in
  Printf.printf "Answer for part 1: %d\n" answer
```

When this is compiled and ran we can confirm that we get the correct answer:

```
Answer for part 1: 142
```

Great! Now on to part two.

## Part 2

### Problem Statement

In a similar way to the first part we need to combine the first and last digit in the string on a line to get a number. However, in part 2 it is also valid if the number is spelled out with letters.

```
two1nine
eightwothree
abcone2threexyz
xtwone3four
4nineeightseven2
zoneight234
7pqrstsixteen
```

Given this input, the first line will have a number `29` because the first spelled out digit is `two` and the last spelled out digit is `nine`. The last line has a number `76` because the first digit is `7` and the last spelled out digit is `six`.

The correct answer for the above input would be: `29 + 83 + 13 + 24 + 42 + 14 + 76 = 281`

### Solution

As a first step we define an association list that maps integer values to their spelled out words:

```ocaml
let digits_to_words =
  [
    (0, "zero");
    (1, "one");
    (2, "two");
    (3, "three");
    (4, "four");
    (5, "five");
    (6, "six");
    (7, "seven");
    (8, "eight");
    (9, "nine");
  ]
```

Next up we want a function that can find each of these spelled out words in the string and return the index and value of the first occurrence:

```ocaml
let find_first_word line digits_to_words =
  (* Find the first occurrence of a word in the line. Check if the index is
     smaller than the smallest index encountered so far and then return it.
     Otherwise it's not the smallest index and we return the current smallest
     index. *)
  let find_word (min_idx, acc_digit) (digit, word) =
    let idx = String.substr_index line ~pattern:word in
    match idx with
    | Some idx -> if idx < min_idx then (idx, digit) else (min_idx, acc_digit)
    | None -> (min_idx, acc_digit)
  in
  let min_idx, acc_digit =
    List.fold digits_to_words ~init:(Int.max_value, Int.max_value) ~f:find_word
  in
  if min_idx = Int.max_value then None else Some (min_idx, acc_digit)

let find_first_word_left line = find_first_word line digits_to_words

(* When we look for the first word from the right, we have to reverse the line
   and the letters of the spelled out numbers we are checking for. *)
let find_first_word_right line =
  find_first_word (String.rev line)
    (List.map digits_to_words ~f:(fun (digit, word) -> (digit, String.rev word)))
```

Take note that `find_first_word_right` has the same logic as `find_first_word_left` except that both the input `line` and the words that are matched against are reversed.

The logic for finding the first digit is similar to part 1:

```ocaml
(* Find the first digit in the line from the left. Return the index of the digit
   as well as its integer value. *)
let find_first_digit_left line =
  match String.findi line ~f:(fun _ c -> Char.is_digit c) with
  | Some (idx, first_digit) -> Some (idx, char_to_int first_digit)
  | None -> None

(* To get the first digit from the right we simply reverse the input line and
   then get the first digit from the left. *)
let find_first_digit_right line = find_first_digit_left (String.rev line)
```

Now we can combine these into one function that can check for both spelled out words and digits:

```ocaml
(* Try to find the first word and the first digit in the string. Pick the one
   with the lowest index and return the value. If none are found, return None. *)
let find_first_num line ~f1 ~f2 =
  match (f1 line, f2 line) with
  | Some (idx1, digit1), Some (idx2, digit2) ->
      if idx1 < idx2 then Some digit1 else Some digit2
  | Some (_, digit1), None -> Some digit1
  | None, Some (_, digit2) -> Some digit2
  | None, None -> None

let find_first_num_left =
  find_first_num ~f1:find_first_word_left ~f2:find_first_digit_left

let find_first_num_right =
  find_first_num ~f1:find_first_word_right ~f2:find_first_digit_right
```

Putting it all together we can parse the input and come up with an answer:

```ocaml
let num_from_line line =
  match (find_first_num_left line, find_first_num_right line) with
  | Some left, Some right -> (left * 10) + right
  | _ -> raise (Failure "Couldn't find a digit in the string")

let sum_lines lines =
  let sum_nums acc line = acc + num_from_line line in
  List.fold lines ~init:0 ~f:sum_nums

let () =
  let lines = In_channel.read_lines "inputs/day_01.txt" in
  let answer = sum_lines lines in
  Printf.printf "Answer for part 2: %d\n" answer
```

For completeness, here is what the entire `.ml` file looks like:

```ocaml
open! Core

let char_to_int digit =
  let zero = Char.to_int '0' in
  Char.to_int digit - zero

(* Association list of spelled out digits and their corresponding integer digit
   values. *)
let digits_to_words =
  [
    (0, "zero");
    (1, "one");
    (2, "two");
    (3, "three");
    (4, "four");
    (5, "five");
    (6, "six");
    (7, "seven");
    (8, "eight");
    (9, "nine");
  ]

let find_first_word line digits_to_words =
  (* Find the first occurrence of a word in the line. Check if the index is
     smaller than the smallest index encountered so far and then return it.
     Otherwise it's not the smallest index and we return the current smallest
     index. *)
  let find_word (min_idx, acc_digit) (digit, word) =
    let idx = String.substr_index line ~pattern:word in
    match idx with
    | Some idx -> if idx < min_idx then (idx, digit) else (min_idx, acc_digit)
    | None -> (min_idx, acc_digit)
  in
  let min_idx, acc_digit =
    List.fold digits_to_words ~init:(Int.max_value, Int.max_value) ~f:find_word
  in
  if min_idx = Int.max_value then None else Some (min_idx, acc_digit)

let find_first_word_left line = find_first_word line digits_to_words

(* When we look for the first word from the right, we have to reverse the line
   and the letters of the spelled out numbers we are checking for. *)
let find_first_word_right line =
  find_first_word (String.rev line)
    (List.map digits_to_words ~f:(fun (digit, word) -> (digit, String.rev word)))

(* Find the first digit in the line from the left. Return the index of the digit
   as well as its integer value. *)
let find_first_digit_left line =
  match String.findi line ~f:(fun _ c -> Char.is_digit c) with
  | Some (idx, first_digit) -> Some (idx, char_to_int first_digit)
  | None -> None

(* To get the first digit from the right we simply reverse the input line and
   then get the first digit from the left. *)
let find_first_digit_right line = find_first_digit_left (String.rev line)

(* Try to find the first word and the first digit in the string. Pick the one
   with the lowest index and return the value. If none are found, return None. *)
let find_first_num line ~f1 ~f2 =
  match (f1 line, f2 line) with
  | Some (idx1, digit1), Some (idx2, digit2) ->
      if idx1 < idx2 then Some digit1 else Some digit2
  | Some (_, digit1), None -> Some digit1
  | None, Some (_, digit2) -> Some digit2
  | None, None -> None

let find_first_num_left =
  find_first_num ~f1:find_first_word_left ~f2:find_first_digit_left

let find_first_num_right =
  find_first_num ~f1:find_first_word_right ~f2:find_first_digit_right

let num_from_line line =
  match (find_first_num_left line, find_first_num_right line) with
  | Some left, Some right -> (left * 10) + right
  | _ -> raise (Failure "Couldn't find a digit in the string")

let sum_lines lines =
  let sum_nums acc line = acc + num_from_line line in
  List.fold lines ~init:0 ~f:sum_nums

let () =
  let lines = In_channel.read_lines "inputs/day_01.txt" in
  let answer = sum_lines lines in
  Printf.printf "Answer for part 2: %d\n" answer
```

Compiling and running this code yields the following result:

```
Answer for part 2: 281
```

### Just a note

Thanks for reading this post on solving the first day of Advent of Code 2023 using OCaml. I am going to experiment this year with writing a lot more blog posts that are shorter-form while timeboxing how much time I spend writing them. I have a habit of spending hours faffing over small details that gets in the way of producing more useful content.

I am working on a lot of cool things in my free time including building a quantitative research platform on my home infrastructure. I am on a journey to learn the functional programming paradigm and absorb that into how I write software. I am also reading some books on quantitative finance and statistics. I have forgotten so much of the mathematics and statistics I learned as a university student and it has been a lot of fun getting back into it.

Bookmark this blog and check back in on occasion if you feel like reading some (hopefully) interesting things about what I've been working on.