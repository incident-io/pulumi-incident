package version

// Version is initialized by the Go linker at build time to the release
// version, so the binary always reports the tag it shipped from.
var Version string
