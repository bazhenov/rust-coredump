use std::collections::HashMap;

fn main() {
    let s = "Some string";
    let s_copy = s.to_owned();
    let v = vec![1, 2, 3];
    let dropped_vector = vec![1, 2, 3];
    drop(dropped_vector);

    let mut map = HashMap::new();
    map.insert(1, "One");
    map.insert(2, "Two");

    some_func();
}

#[inline(always)]
fn some_func() {
    std::process::abort();
}
