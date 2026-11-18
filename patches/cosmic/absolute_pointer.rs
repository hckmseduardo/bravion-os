// Parallels' absolute USB pointer addresses the complete guest desktop.
// Other absolute devices retain COSMIC's active-output mapping.
pub fn map_absolute_pointer(
    device: &str,
    normalized: (f64, f64),
    outputs: &[(i32, i32, i32, i32)],
    active: usize,
) -> Option<(usize, (f64, f64))> {
    let &(ax, ay, aw, ah) = outputs.get(active)?;
    if device != "Parallels Virtual Mouse" {
        return Some((active, (ax as f64 + normalized.0 * aw as f64, ay as f64 + normalized.1 * ah as f64)));
    }
    let left = outputs.iter().map(|r| r.0).min()? as f64;
    let top = outputs.iter().map(|r| r.1).min()? as f64;
    let right = outputs.iter().map(|r| r.0 + r.2).max()? as f64;
    let bottom = outputs.iter().map(|r| r.1 + r.3).max()? as f64;
    let px = (left + normalized.0 * (right-left)).clamp(left, right-1.0);
    let py = (top + normalized.1 * (bottom-top)).clamp(top, bottom-1.0);
    // Project gaps between unequal-sized monitors onto the nearest visible pixel.
    outputs.iter().enumerate().filter(|(_,r)| r.2 > 0 && r.3 > 0).map(|(i,r)| {
        let x = px.clamp(r.0 as f64, (r.0+r.2-1) as f64);
        let y = py.clamp(r.1 as f64, (r.1+r.3-1) as f64);
        (i, (x,y), (px-x).powi(2)+(py-y).powi(2))
    }).min_by(|a,b| a.2.total_cmp(&b.2)).map(|(i,p,_)| (i,p))
}

#[cfg(test)]
mod tests {
    use super::*;
    const PAIR: [(i32,i32,i32,i32);2] = [(0,0,1920,1080),(1920,0,1920,1080)];
    #[test]
    fn parallels_can_reach_second_monitor_without_prior_focus() {
        assert_eq!(map_absolute_pointer("Parallels Virtual Mouse", (0.75,0.5), &PAIR, 0), Some((1,(2880.0,540.0))));
    }
    #[test]
    fn parallels_can_return_to_first_monitor() {
        assert_eq!(map_absolute_pointer("Parallels Virtual Mouse", (0.25,0.5), &PAIR, 1), Some((0,(960.0,540.0))));
    }
    #[test]
    fn right_edge_stays_on_desktop() {
        assert_eq!(map_absolute_pointer("Parallels Virtual Mouse", (1.0,1.0), &PAIR, 0), Some((1,(3839.0,1079.0))));
    }
    #[test]
    fn generic_tablet_keeps_active_output_mapping() {
        assert_eq!(map_absolute_pointer("Drawing Tablet", (0.5,0.5), &PAIR, 1), Some((1,(2880.0,540.0))));
    }
    #[test]
    fn negative_output_origin_is_supported() {
        let outputs = [(-1920,0,1920,1080),(0,0,1920,1080)];
        assert_eq!(map_absolute_pointer("Parallels Virtual Mouse", (0.25,0.5), &outputs, 1), Some((0,(-960.0,540.0))));
    }
}
