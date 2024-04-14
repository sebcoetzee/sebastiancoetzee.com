---
layout: post
title: Advent of Code 2023 in OCaml - Day 2
---

![OCaml logo](../img/posts/ocaml.png){: width="100%" }

This is the second in the series of [Advent of Code 2023](https://adventofcode.com/2023) in [OCaml](https://ocaml.org/). If you're interested, take a look at [Day 1](/2024-03-16-advent-of-code-ocaml-2023-day-1). Let's jump straight in.

**Note:** I will be using Jane Street's [core](https://ocaml.org/p/core/latest) library as a replacement for OCaml's standard library.

## Part 1

### Problem Statement

We're given text input that details a number of games played. Each game has an ID. A game consists of multiple rounds of cubes being drawn from a bag. Each cube has one of three colours: red, blue, or green.

We need to determine which games would have been possible if the bag contained 12 red cubes, 13 green cubes, and 14 blue cubes.

Example input:

```
Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
```

Correct answer:

```
Game 1: possible
Game 2: possible
Game 3: not possible
Game 4: not possible
Game 5: possible
```

To get the answer we need to add up the game IDs of the games that were possible. For the above example this would be `1 + 2 + 5 = 8`.

### Solution

In this example I will use Jane Street's [ppx_inline_test](https://github.com/janestreet/ppx_inline_test) syntax extension to allow us to easily write inline tests for the functions. We can run these using `dune runtest`.

To begin with I'll declare a variant type `colour` for the different colours, a function `match_colour` for mapping string names of colours to their colour types, a record type `draw_results` that we can use to store the results of the draws in a round, and `max_counts` which is an instance of the `draw_results` record type that defines the max number of each colour cube that is available:

```ocaml
open! Core

type colour =
  | Red
  | Green
  | Blue

(* Match a string colour name with its type counterpart *)
let match_colour = function
  | "red" -> Red
  | "green" -> Green
  | "blue" -> Blue
  | _ -> raise (Failure "Invalid colour")
;;

type draw_results =
  { red : int
  ; green : int
  ; blue : int
  }

(* Max counts of each type allowed in a game *)
let max_counts = { red = 12; green = 13; blue = 14 }
```

We can use a regular expression pattern to extract the game ID from the line:

```ocaml
(* Extract the game ID from the line *)
let game_id line =
  let game_id_regex = Str.regexp {|^Game \([0-9]+\): |} in
  let _ = Str.string_match game_id_regex line 0 in
  Str.matched_group 1 line |> Int.of_string
;;

let%test "extract game id 5" =
  Poly.equal (game_id "Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green") 5
;;
```

We can use a regular expression pattern to parse a single draw. Take note of the test cases:

```ocaml
let parse_draw draw =
  let draw_regex = Str.regexp {|\([0-9]+\) \(red\|green\|blue\)|} in
  let _ = Str.search_forward draw_regex draw 0 in
  let num_str = Str.matched_group 1 draw in
  let colour_str = Str.matched_group 2 draw in
  match_colour colour_str, Int.of_string num_str
;;

let%test "parse 1 red" = Poly.equal (parse_draw "1 red") (Red, 1)
let%test "parse 3 blue" = Poly.equal (parse_draw "3 blue") (Blue, 3)
let%test "parse 2 green" = Poly.equal (parse_draw "2 green") (Green, 2)
```

Iterating through all the draws in a round, the results of a round are collected:

```ocaml
let parse_round round =
  let accumulate_draws acc = function
    | Red, count -> { acc with red = count }
    | Green, count -> { acc with green = count }
    | Blue, count -> { acc with blue = count }
  in
  String.split round ~on:','
  |> List.map ~f:parse_draw
  |> List.fold ~init:{ red = 0; green = 0; blue = 0 } ~f:accumulate_draws
;;

let%test "parse 1 red, 2 green" =
  Poly.equal (parse_round "1 red, 2 green") { red = 1; green = 2; blue = 0 }
;;

let%test "parse 1 red, 2 green, 5 blue" =
  Poly.equal (parse_round "1 red, 2 green, 5 blue") { red = 1; green = 2; blue = 5 }
;;

let%test "parse with game ID" =
  Poly.equal (parse_round "Game 5: 6 red, 1 blue, 3 green") { red = 6; green = 3; blue = 1 }
;;

(*
   Parse string representation of a game into a list of typed results.
   For example '1 red, 2 green; 4 red, 2 blue'
*)
let parse_game line = String.split line ~on:';' |> List.map ~f:parse_round
```

To validate whether a game is possible, each round has to be individually validated against `max_draw_results`:

```ocaml
(* Validate that all of the draws were possible *)
let validate_game =
  let validate_draw_results results =
    results.red <= max_counts.red
    && results.green <= max_counts.green
    && results.blue <= max_counts.blue
  in
  List.for_all ~f:validate_draw_results
;;

let%test "validate an invalid game" =
  not (validate_game [ { red = 6; green = 3; blue = 1 }; { red = 6; green = 3; blue = 15 } ])
;;

let%test "validate an valid game" = validate_game [ { red = 6; green = 3; blue = 1 } ]
```

We now have all the building blocks necessary to add up all the valid game IDs:

```ocaml
let () =
  let accumulate_valid_game_ids acc line =
    if line |> parse_game |> validate_game then acc + game_id line else acc
  in
  In_channel.create "inputs/day_02.txt"
  |> In_channel.fold_lines ~init:0 ~f:accumulate_valid_game_ids
  |> Printf.printf "Answer for part 1: %d\n"
;;
```

Running this code we get the following answer:

```
Answer for part 1: 8
```

Correct! 🎉🐪 Now, let's move onto part 2.

## Part 2

### Problem Statement

The second part involves calculating the minimum number of each colour cube that would be sufficient to have in the bag at the start of each game. For the input above, we need the following minimum numbers of cubes in the bag:

```
Game 1: 4 red, 6 blue, 2 green
Game 2: 1 red, 4 blue, 3 green
Game 3: 20 red, 13 green, 6 blue
Game 4: 14 red, 3 green, 15 blue
Game 5: 6 red, 3 green, 2 blue
```

To get the final answer we have to sum the products of these numbers for each game:

```
Game 1: 4 * 6 * 2 = 48
Game 2: 1 * 4 * 3 = 12
Game 3: 20 * 13 * 6 = 1560
Game 4: 14 * 3 * 15 = 630
Game 5: 6 * 3 * 2 = 36
Total = 2286
```

### Solution

```ocaml
(*
   To calculate the game power we need to calculate the minimum number of cubes of
   each colour we would've needed in order to make it possible to play each game.
   The power of each game is the product of the minimum of each cube number.
*)
let game_power game =
  let max_draws acc round =
    { red = max acc.red round.red
    ; green = max acc.green round.green
    ; blue = max acc.blue round.blue
    }
  in
  game
  |> parse_game
  |> List.fold ~init:{ red = 0; green = 0; blue = 0 } ~f:max_draws
  |> fun { red; green; blue } -> red * green * blue
;;

let%test "validate game power calculation" =
  game_power "Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green" = 36
;;
```

Let's use the `game_power` function to calculate the answer:

```ocaml
let () =
  let accumulate_game_power acc line = acc + game_power line in
  In_channel.create "inputs/day_02.txt"
  |> In_channel.fold_lines ~init:0 ~f:accumulate_game_power
  |> Printf.printf "Answer for part 2: %d\n"
;;
```

Running this we get:

```
Answer for part 2: 2286
```

Correct! 🎉🐪