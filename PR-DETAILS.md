## Description

This PR introduces two independent Clarity smart contracts that form a blockchain-based accountability system for developer learning patterns. The system tracks tutorial consumption behavior and side project lifecycle management.

## Changes

### Smart Contracts Implemented

**1. tutorial-completion-abandonment-tracker.clar (241 lines)**
- Tracks tutorial starts, completions, and abandonments
- Records precise timestamps using Stacks block heights
- Calculates user-specific and global completion rates
- Stores abandonment reasons and minutes watched
- Maintains per-user tutorial indexes for easy retrieval

**2. side-project-graveyard-memorial.clar (374 lines)**
- Creates permanent records of side projects
- Tracks commit activity and calculates inactivity periods
- Generates contextual project obituaries based on lifecycle
- Supports project completion and retirement workflows
- Maintains comprehensive user and global statistics

## Technical Implementation

### Data Structures
- **Tutorial Map**: Stores tutorial metadata with owner, title, source, timestamps, status, and engagement metrics
- **Project Map**: Maintains project details including commits, inactivity calculations, and obituaries
- **User Stats Maps**: Aggregate statistics per user for both tutorials and projects
- **Index Maps**: Enable efficient querying of user-specific data

### Key Features
- No cross-contract dependencies (fully independent contracts)
- Pure Clarity implementation without traits
- Block height-based timestamp tracking
- Automatic calculation of completion rates and inactivity periods
- Owner-based access control for modifications
- Comprehensive read-only query functions

### Status Management
Both contracts implement status-based workflows:
- Tutorial states: in-progress → completed/abandoned
- Project states: active → completed/abandoned/retired

## Testing & Validation
- ✅ Contracts pass `clarinet check` validation
- ✅ Proper error handling with descriptive error codes
- ✅ Authorization checks on all state-changing operations
- ✅ Line endings normalized to LF format

## Future Enhancements
- Integration with GitHub API for automatic commit tracking
- Web interface for data visualization
- Statistical analysis tools for learning patterns
- Community leaderboards and challenges

## Co-authored-by
Co-Authored-By: Warp <agent@warp.dev>
