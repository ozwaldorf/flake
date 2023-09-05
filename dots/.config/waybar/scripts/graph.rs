#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! psutil = "3.2.2"
//! ```

use psutil::{cpu::CpuPercentCollector, memory::virtual_memory};
use std::{env::args, str::FromStr, thread::sleep, time::Duration};

const CHARS: &[char] = &['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'];
const WIDTH: usize = 7;
const USAGE: &str = "Usage: ./graph.rs <cpu|ram> [delay]";

struct Printer<'a> {
    subtext: &'a str,
    buf: String,
    last: String,
}

impl<'a> Printer<'a> {
    fn new(subtext: &'a str) -> Self {
        Self {
            subtext,
            buf: String::from_iter(vec![' '; WIDTH]),
            last: String::with_capacity(WIDTH),
        }
    }

    fn update(&mut self, value: f32) {
        let idx = ((CHARS.len() as f32 - 1.0) * value / 100.0).round() as usize;
        let current = CHARS[idx].clone();
        self.buf.push(current);
        self.buf.remove(0);

        if self.buf != self.last {
            // println!(
            //     r#"{{"text":"{}\n{}{}", "alt": "{value:.01}"}}"#,
            //     self.buf,
            //     self.subtext,
            //     value.round(),
            // );
            println!(r#"{{"text":"{}", "alt": "{value:.01}"}}"#, self.buf);

            self.last = self.buf.clone();
        }
    }
}

fn main() {
    let args: Vec<_> = args().collect();
    let mode = args.get(1).expect(USAGE);
    let delay = args
        .get(2)
        .map(|arg| Duration::from_millis(u64::from_str(arg).expect(USAGE)))
        .unwrap_or(Duration::from_millis(200));

    let mut printer = Printer::new(&mode);

    match mode.to_lowercase().as_str() {
        "cpu" => {
            let mut cpuinfo = CpuPercentCollector::new().unwrap();
            loop {
                let val = cpuinfo.cpu_percent().unwrap();
                printer.update(val);
                sleep(delay);
            }
        }
        "ram" => loop {
            let info = virtual_memory().unwrap();
            printer.update(info.percent());
            sleep(delay);
        },
        _ => {
            panic!("{USAGE}")
        }
    }
}
