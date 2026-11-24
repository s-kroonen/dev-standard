pub fn clamp_channel(v: i32) -> u8 {
    v.clamp(0, 255) as u8
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[ignore]
    fn clamps_high() {
        assert_eq!(clamp_channel(300), 255);
    }
}
