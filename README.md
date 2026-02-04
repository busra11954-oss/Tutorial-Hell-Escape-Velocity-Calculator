# Tutorial Hell Escape Velocity Calculator

A blockchain-based accountability system built on the Stacks blockchain using Clarity smart contracts. This project helps developers track their learning progress by measuring the ratio between tutorials consumed and actual projects completed.

## Overview

The Tutorial Hell Escape Velocity Calculator is designed to combat "tutorial hell" - the endless cycle of watching tutorials without building real projects. By tracking tutorial completions versus actual project deployments on an immutable blockchain, developers can visualize their progress and hold themselves accountable.

## Core Concepts

### Tutorial Completion Abandonment Tracker
Tracks the exact moment developers abandon tutorials, recording:
- Tutorial title and timestamp when started
- Exact minute of abandonment
- Reason for switching (optional)
- Cumulative abandonment statistics

### Side Project Graveyard Memorial
Maintains a permanent record of unfinished projects:
- Project name and description
- Creation timestamp
- Last commit timestamp
- Days of inactivity
- Project obituary generation

## Smart Contracts

### 1. tutorial-completion-abandonment-tracker.clar
Monitors tutorial consumption patterns and abandonment behavior. Records tutorial starts, completions, and abandonments with precise timestamps to help developers identify problematic patterns.

**Key Features:**
- Track tutorial starts with metadata
- Record abandonment points with timestamps
- Calculate completion rates
- Generate insights on abandonment patterns

### 2. side-project-graveyard-memorial.clar
A memorial for abandoned side projects that creates permanent records of unfinished work, encouraging developers to either complete or officially retire projects.

**Key Features:**
- Register new side projects
- Update project status with commits
- Calculate days of inactivity
- Generate project obituaries
- Track total project graveyard size

## Architecture

The system uses two independent smart contracts that don't interact with each other, focusing on:
- **Data Integrity**: Immutable records on the Stacks blockchain
- **Privacy**: User controls their own data
- **Accountability**: Transparent tracking of learning habits
- **Simplicity**: No cross-contract calls or complex trait systems

## Technology Stack

- **Blockchain**: Stacks (Bitcoin Layer 2)
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet
- **Testing**: Vitest with Clarinet SDK

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js (v16 or higher)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/busra11954-oss/Tutorial-Hell-Escape-Velocity-Calculator.git

# Navigate to project directory
cd Tutorial-Hell-Escape-Velocity-Calculator

# Install dependencies
npm install
```

### Development

```bash
# Check contract syntax
clarinet check

# Run tests
npm test

# Start local devnet
clarinet integrate
```

## Contract Interactions

### Tutorial Tracker
```clarity
;; Start tracking a new tutorial
(contract-call? .tutorial-completion-abandonment-tracker start-tutorial "Building React Apps" "Tutorial Hell Productions")

;; Record abandonment
(contract-call? .tutorial-completion-abandonment-tracker abandon-tutorial u1 "Switched to TypeScript version")

;; Complete a tutorial
(contract-call? .tutorial-completion-abandonment-tracker complete-tutorial u1)
```

### Project Memorial
```clarity
;; Register a new side project
(contract-call? .side-project-graveyard-memorial register-project "My Blog" "Personal tech blog with MDX")

;; Update with commit activity
(contract-call? .side-project-graveyard-memorial record-commit u1)

;; Generate obituary
(contract-call? .side-project-graveyard-memorial generate-obituary u1)
```

## Use Cases

1. **Self-Accountability**: Track your learning-to-building ratio
2. **Habit Analysis**: Identify tutorial abandonment patterns
3. **Progress Visualization**: See your project completion trends
4. **Community Challenges**: Compare stats with other developers
5. **Portfolio Cleanup**: Officially retire dead projects

## Data Privacy

- All data is user-controlled and stored on-chain
- No personal information required beyond Stacks address
- Users can choose to share or keep data private
- Immutable records ensure data integrity

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## License

MIT License - feel free to use this project for your own learning accountability journey.

## Acknowledgments

Inspired by every developer who has ever started 47 tutorials and finished none. We've all been there.

---

**Remember**: The only way out of tutorial hell is to build. This tool helps you measure your escape velocity.
