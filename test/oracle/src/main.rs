//! Slice8 differential oracle binary.
//!
//! Reads a serialised document from stdin (the wire format shared with the
//! Erlang driver, `pe_oracle_mjl`), builds the corresponding mjl
//! `pretty-expressive` `Doc`, renders it with
//! `DefaultCostFactory::new(width, Some(limit))`, and prints the chosen layout
//! to stdout. On an unprintable document it prints the `<<FAIL>>` sentinel.
//!
//! Wire format (ASCII, prefix S-expressions):
//!   D := (t "STR") | (nl) | (brk) | (hnl) | (fail)
//!      | (cat D D) | (nest N D) | (align D) | (reset D)
//!      | (cost B H D) | (alt D D)
//! where STR uses `\"` and `\\` escapes, and N/B/H are non-negative integers.
//!
//! Usage: `pe-oracle WIDTH LIMIT [FILE]` — document read from FILE, or stdin if
//! omitted.

use std::io::Read;

use pretty_expressive::{
    align, brk, cost, fail, hard_nl, nest, nl, reset, text, DefaultCost, DefaultCostFactory, Doc,
};

fn main() {
    let mut args = std::env::args().skip(1);
    let width: usize = args
        .next()
        .and_then(|s| s.parse().ok())
        .expect("usage: pe-oracle WIDTH LIMIT [FILE]");
    let limit: usize = args
        .next()
        .and_then(|s| s.parse().ok())
        .expect("usage: pe-oracle WIDTH LIMIT [FILE]");

    let input = match args.next() {
        Some(path) => std::fs::read_to_string(&path).expect("read doc file"),
        None => {
            let mut s = String::new();
            std::io::stdin().read_to_string(&mut s).expect("read stdin");
            s
        }
    };

    let mut parser = Parser::new(&input);
    let doc = parser.parse();
    parser.skip_ws();
    assert!(parser.at_end(), "trailing input after document");

    match doc.validate_with_cost(DefaultCostFactory::new(width, Some(limit))) {
        Ok(result) => print!("{result}"),
        Err(_) => print!("<<FAIL>>"),
    }
}

struct Parser<'a> {
    bytes: &'a [u8],
    pos: usize,
}

impl<'a> Parser<'a> {
    fn new(s: &'a str) -> Self {
        Parser {
            bytes: s.as_bytes(),
            pos: 0,
        }
    }

    fn at_end(&self) -> bool {
        self.pos >= self.bytes.len()
    }

    fn peek(&self) -> u8 {
        self.bytes[self.pos]
    }

    fn skip_ws(&mut self) {
        while self.pos < self.bytes.len() && self.bytes[self.pos].is_ascii_whitespace() {
            self.pos += 1;
        }
    }

    fn expect(&mut self, c: u8) {
        self.skip_ws();
        assert_eq!(self.peek(), c, "expected `{}`", c as char);
        self.pos += 1;
    }

    fn parse(&mut self) -> Doc {
        self.expect(b'(');
        self.skip_ws();
        let tag = self.symbol();
        let doc = match tag.as_str() {
            "t" => text(self.string()),
            "nl" => nl(),
            "brk" => brk(),
            "hnl" => hard_nl(),
            "fail" => fail(),
            "cat" => {
                let a = self.parse();
                let b = self.parse();
                a & b
            }
            "alt" => {
                let a = self.parse();
                let b = self.parse();
                a | b
            }
            "nest" => {
                let n = self.int();
                let d = self.parse();
                nest(n, d)
            }
            "align" => align(self.parse()),
            "reset" => reset(self.parse()),
            "cost" => {
                let b = self.int() as i32;
                let h = self.int() as i32;
                let d = self.parse();
                cost(DefaultCost(b, h), d)
            }
            other => panic!("unknown tag `{other}`"),
        };
        self.expect(b')');
        doc
    }

    fn symbol(&mut self) -> String {
        self.skip_ws();
        let start = self.pos;
        while self.pos < self.bytes.len() {
            let c = self.bytes[self.pos];
            if c.is_ascii_whitespace() || c == b'(' || c == b')' {
                break;
            }
            self.pos += 1;
        }
        String::from_utf8(self.bytes[start..self.pos].to_vec()).expect("ascii symbol")
    }

    fn int(&mut self) -> usize {
        self.symbol().parse().expect("integer")
    }

    fn string(&mut self) -> String {
        self.skip_ws();
        self.expect_no_ws(b'"');
        let mut s = String::new();
        loop {
            let c = self.bytes[self.pos];
            self.pos += 1;
            match c {
                b'"' => break,
                b'\\' => {
                    let e = self.bytes[self.pos];
                    self.pos += 1;
                    s.push(e as char);
                }
                other => s.push(other as char),
            }
        }
        s
    }

    fn expect_no_ws(&mut self, c: u8) {
        assert_eq!(self.peek(), c, "expected `{}`", c as char);
        self.pos += 1;
    }
}
