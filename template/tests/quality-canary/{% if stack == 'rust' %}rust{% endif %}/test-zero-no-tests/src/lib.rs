pub fn clamp_channel(v: i32) -> u8 {
    v.clamp(0, 255) as u8
}
