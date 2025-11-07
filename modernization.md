# Basilisk II ARM64 Modernization Roadmap

## Quick Status Overview

### Implementation Order (Easy to Hard, Visible Impact First)

#### Stage 1: Quick Wins (1-2 hours each)
1. [ ] **ARM64 unaligned access** - One line change, 5-10% faster
2. [ ] **Xcode compiler flags** - 15 min work, 5-10% faster  
3. [ ] **Fix quit issue** - Event loop fix, immediately noticeable

#### Stage 2: Visible Improvements (2-4 hours each)
4. [x] **Fix yellow screen bug** - RGBA channel order, FIXED!
5. [x] **Fix color depth parsing** - Games now detect correct color modes
6. [ ] **Fix audio/sound issue** - SDL audio not producing sound
7. [ ] **ARM64 byte swapping** - Assembly optimization, 10-15% faster
8. [ ] **Add memory barriers** - Stability improvement

#### Stage 3: User Experience (1-2 days each)
9. [ ] **ROM file picker** - Native file dialog
10. [ ] **Drag-and-drop disk mounting** - Like vMac
11. [ ] **Modern preferences GUI** - Replace text file config
12. [ ] **Project structure cleanup** - Move xcodeproj to root, remove other platforms

#### Stage 4: Major Refactoring (1-2 weeks each)
13. [ ] **Replace SDL2 video with Metal** - Native rendering
14. [ ] **Replace SDL audio with CoreAudio** - Lower latency
15. [ ] **Full macOS integration** - Notifications, services, etc.

### Current Sprint: Stage 1 (This Week)
- [ ] ARM64 unaligned access support
- [ ] Xcode compiler flags for ARM64
- [ ] Fix application quit issue

### User-Reported Issues (CRITICAL)
- [x] **Display color corruption** - FIXED! Changed ARGB to BGRA
- [x] **Color depth detection** - FIXED! Games now detect correct modes
- [ ] **Audio not working** - SDL audio initialized but no sound output
- [ ] **Cannot quit application** - Must force quit to exit
- [ ] **Outdated preferences** - ~/.basilisk_ii_prefs file is old-school, needs GUI
- [ ] **ROM file selection** - Need easier ROM file picker
- [ ] **No drag-and-drop** - Disk mounting should support drag-and-drop like vMac

### Long-term Vision
- [ ] Replace SDL2 with native Metal rendering
- [ ] Replace SDL audio with CoreAudio
- [ ] Modern macOS UI with native controls
- [ ] Full macOS integration (drag-drop, notifications, etc.)

---

## Critical Priority (P0) - Immediate Action Required

### 0. Fix Critical Bugs (NEW - HIGHEST PRIORITY)
**Status:** Broken, needs immediate fix
**Impact:** User experience, basic functionality
**Effort:** Low to Medium

#### Issue 1: Yellow/Color Channel Bug
- [ ] Investigate RGBA vs BGRA channel order in video output
- [ ] Check frame buffer format in `src/MacOSX/video_macosx.mm`
- [ ] Verify SDL2 pixel format configuration
- [ ] Test with different color depths

**Files to check:**
- `src/MacOSX/video_macosx.mm`
- `src/SDL/video_sdl2.cpp`
- `src/CrossPlatform/video_blit.cpp`

#### Issue 2: Cannot Quit Application
- [ ] Check event loop handling in main_macosx.mm
- [ ] Verify signal handlers are not blocking quit
- [ ] Add proper cleanup in application termination
- [ ] Test Cmd+Q and menu quit options

**Files to check:**
- `src/MacOSX/main_macosx.mm`
- `src/Unix/main_unix.cpp`
- `src/MacOSX/Controller.mm`

#### Issue 3: Modernize Preferences System
- [ ] Replace ~/.basilisk_ii_prefs with modern storage (~/Library/Preferences)
- [ ] Create native macOS preferences window
- [ ] Add ROM file picker dialog
- [ ] Add disk image picker with preview

**Files to modify:**
- `src/MacOSX/PrefsEditor.mm`
- `src/MacOSX/prefs_macosx.cpp`
- `src/prefs.cpp`

#### Issue 4: Drag-and-Drop Support
- [ ] Implement drag-and-drop for disk images
- [ ] Support .dsk, .img, .iso file types
- [ ] Add visual feedback during drag operation
- [ ] Auto-mount dropped disk images

**Files to modify:**
- `src/MacOSX/EmulatorView.mm`
- `src/MacOSX/Controller.mm`
- `src/disk.cpp`

### 1. ARM64 Architecture Support
**Status:** Partially implemented, needs optimization
**Impact:** Performance, stability
**Effort:** Medium

- [ ] Add ARM64 to CPU_CAN_ACCESS_UNALIGNED definition in `src/Unix/sysdeps.h`
- [ ] Implement ARM64-optimized byte swapping using REV/REV16 instructions
- [ ] Add memory barrier macros for ARM64 weak memory model
- [ ] Test unaligned memory access on Apple Silicon

**Files to modify:**
- `src/Unix/sysdeps.h` (lines 216, 424+)
- `src/BeOS/sysdeps.h` (if applicable)

### 2. Xcode Build Configuration
**Status:** Basic Universal Binary support exists
**Impact:** Performance
**Effort:** Low

- [ ] Add ARM64-specific compiler flags (-mcpu=apple-m1)
- [ ] Enable Link-Time Optimization (LTO) for Release builds
- [ ] Verify optimization level is set to -O3 for Release
- [ ] Add architecture-specific build settings

**Files to modify:**
- `src/MacOSX/BasiliskII.xcodeproj/project.pbxproj`

### 3. JIT Compiler Status Documentation
**Status:** Not documented
**Impact:** User expectations
**Effort:** Low

- [ ] Document that JIT is x86/x86_64 only
- [ ] Add runtime detection and warning if user expects JIT on ARM64
- [ ] Update README with performance expectations for ARM64

**Files to modify:**
- `README.md`
- `src/MacOSX/config.h` (add comments)

---

## High Priority (P1) - Near-term Goals

### 4. SIGSEGV Handler Improvements
**Status:** Basic ARM64 support exists
**Impact:** Stability, debugging
**Effort:** Medium

- [ ] Enhance aarch64_skip_instruction() with proper instruction decoding
- [ ] Add comprehensive fault address handling for ARM64
- [ ] Implement register file access for ARM64 debugging
- [ ] Test with various memory access patterns

**Files to modify:**
- `src/CrossPlatform/sigsegv.cpp` (lines 2515-2522)
- `src/CrossPlatform/sigsegv.h`

### 5. Memory Management Optimization
**Status:** Generic implementation
**Impact:** Performance
**Effort:** Medium

- [ ] Verify vm_allocate() works optimally on ARM64
- [ ] Test mmap() vs vm_allocate() performance on Apple Silicon
- [ ] Implement proper cache line alignment for ARM64 (128 bytes)
- [ ] Add prefetch hints for critical paths

**Files to modify:**
- `src/CrossPlatform/vm_alloc.cpp`
- `src/Unix/sys_unix.cpp`

### 6. SDL2 Video Backend
**Status:** Implemented but needs testing
**Impact:** Compatibility, performance
**Effort:** Low

- [ ] Verify SDL2 works correctly on ARM64 macOS
- [ ] Test Metal vs OpenGL rendering performance
- [ ] Optimize frame buffer format conversions
- [ ] Add Retina display support

**Files to modify:**
- `src/SDL/video_sdl2.cpp`
- `src/MacOSX/video_macosx.mm`

---

## Medium Priority (P2) - Quality of Life

### 7. macOS Integration
**Status:** Basic functionality exists
**Impact:** User experience
**Effort:** High

- [ ] Implement proper clipboard support (clip_macosx64.mm)
- [ ] Add drag-and-drop file support
- [ ] Implement native file dialogs
- [ ] Add macOS notification integration

**Files to modify:**
- `src/MacOSX/clip_macosx64.mm`
- `src/MacOSX/extfs_macosx.cpp`

### 8. Audio System
**Status:** SDL audio implemented
**Impact:** User experience
**Effort:** Medium

- [ ] Test SDL audio latency on ARM64
- [ ] Implement CoreAudio backend for lower latency
- [ ] Fix last buffer not playing issue
- [ ] Add runtime audio format switching

**Files to modify:**
- `src/SDL/audio_sdl.cpp`
- `src/MacOSX/audio_macosx.cpp` (if implementing CoreAudio)

### 9. Preferences System
**Status:** Functional but dated
**Impact:** User experience
**Effort:** Medium

- [ ] Modernize preferences UI for macOS
- [ ] Add preset configurations (Mac Classic, Mac II, etc.)
- [ ] Implement disk image creation wizard
- [ ] Add validation for user inputs

**Files to modify:**
- `src/MacOSX/PrefsEditor.mm`
- `src/prefs.cpp`

---

## Low Priority (P3) - Future Enhancements

### 10. Code Modernization
**Status:** C++98 codebase
**Impact:** Maintainability
**Effort:** High

- [ ] Migrate to C++17 standard
- [ ] Replace raw pointers with smart pointers where appropriate
- [ ] Use std::thread instead of pthreads
- [ ] Add proper RAII patterns

**Files to review:**
- All `.cpp` and `.h` files

### 11. Testing Infrastructure
**Status:** No automated tests
**Impact:** Quality assurance
**Effort:** High

- [ ] Add unit tests for CPU emulation
- [ ] Create integration tests for common operations
- [ ] Add performance benchmarks
- [ ] Set up CI/CD pipeline

**New files to create:**
- `tests/` directory structure
- GitHub Actions workflow

### 12. Documentation
**Status:** Minimal
**Impact:** Developer onboarding
**Effort:** Medium

- [ ] Document build process for ARM64
- [ ] Add architecture overview
- [ ] Create contribution guidelines
- [ ] Document known issues and workarounds

**Files to create/update:**
- `docs/BUILDING_ARM64.md`
- `docs/ARCHITECTURE.md`
- `CONTRIBUTING.md`

---

## Performance Optimization Targets

### Baseline Measurements Needed
- [ ] Benchmark current ARM64 performance vs x86_64 with Rosetta 2
- [ ] Profile hotspots using Instruments
- [ ] Measure memory bandwidth utilization
- [ ] Test with various Mac ROM versions

### Expected Performance Gains
- Unaligned access support: +5-10%
- ARM64 byte swapping: +10-15%
- Compiler optimizations: +5-10%
- **Total estimated improvement: 20-35%**

---

## Technical Debt

### Code Quality Issues
1. Mixed coding styles (need style guide)
2. Inconsistent error handling
3. Global state management
4. Memory leak potential in error paths

### Platform-Specific Concerns
1. Hardcoded x86 assumptions in multiple files
2. Endianness handling could be cleaner
3. Thread synchronization needs review for ARM64
4. Signal handling complexity

---

## Dependencies to Update

### Current Versions (need verification)
- SDL2: Check version and update if needed
- Compiler: Ensure Xcode 14+ for best ARM64 support
- macOS SDK: Target macOS 11.0+ for full ARM64 features

### Recommended Updates
- [ ] Update SDL2 to latest stable (2.28.x)
- [ ] Set minimum macOS version to 11.0 (Big Sur)
- [ ] Update Xcode project format if needed

---

## Notes

### JIT Compiler Considerations
The x86-only JIT compiler cannot be easily ported to ARM64 due to:
- 110KB+ of x86-specific assembly code
- Complex register allocation for x86 architecture
- Instruction encoding specific to x86

**Decision:** Keep interpreter-only mode for ARM64. Performance is acceptable for 68k emulation given modern ARM64 CPU speeds.

### Memory Model Differences
ARM64 has a weaker memory model than x86:
- Requires explicit barriers for synchronization
- Out-of-order execution more aggressive
- Cache coherency protocols different

**Action:** Add proper memory barriers in critical sections.

### Apple Silicon Specific Features
- Unified memory architecture
- Rosetta 2 translation cache
- Metal graphics API
- Neural Engine (not applicable for this project)

---

## Success Criteria

### Phase 1 (P0 items)
- [ ] 20%+ performance improvement on ARM64
- [ ] No crashes during normal operation
- [ ] Universal binary runs on both Intel and Apple Silicon

### Phase 2 (P1 items)
- [ ] Stable video output at 60fps
- [ ] Audio working without glitches
- [ ] Proper error handling and user feedback

### Phase 3 (P2-P3 items)
- [ ] Modern macOS integration complete
- [ ] Comprehensive documentation
- [ ] Active community contributions

---

## Timeline Estimate

- **P0 items:** 1-2 weeks
- **P1 items:** 3-4 weeks
- **P2 items:** 6-8 weeks
- **P3 items:** Ongoing

**Total for core modernization:** 2-3 months of focused development

---

Last updated: 2025-11-07
