import Testing

extension Tag {
    /// L3 – golden snapshots.
    @Tag static var golden: Self
    /// L2 – invariants measured off a render.
    @Tag static var layout: Self
}
