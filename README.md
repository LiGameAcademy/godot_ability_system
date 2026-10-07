# Godot Gameplay Ability System

**A high-cohesion, low-coupling gameplay ability system plugin for Godot**

[English](README.md) | [中文](README_zh.md)

[![Godot Engine](https://img.shields.io/badge/Godot-4.5+-478CBF?style=flat&logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Plugin Version](https://img.shields.io/badge/version-0.0.1-blue.svg)](plugin.cfg)
[![GitHub stars](https://img.shields.io/github/stars/LiGameAcademy/godot_ability_system?style=flat)](https://github.com/LiGameAcademy/godot_ability_system/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/LiGameAcademy/godot_ability_system?style=flat)](https://github.com/LiGameAcademy/godot_ability_system/network/members)
[![GitHub issues](https://img.shields.io/github/issues/LiGameAcademy/godot_ability_system)](https://github.com/LiGameAcademy/godot_ability_system/issues)
[![GitHub last commit](https://img.shields.io/github/last-commit/LiGameAcademy/godot_ability_system)](https://github.com/LiGameAcademy/godot_ability_system/commits)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/LiGameAcademy/godot_ability_system/pulls)

<p align="center">
  <a href="https://godotengine.org/">
    <img src="https://godotengine.org/assets/press/logo_large_color_dark.png" alt="Made with Godot" width="200">
  </a>
</p>

## Introduction

Godot Gameplay Ability System is a feature-complete, well-architected ability system plugin designed for Godot 4.5+. It follows a **data-driven**, **component-based**, **decoupled**, and **extensible** design philosophy, giving developers a powerful and flexible framework for building ability systems.

Inspired by Unreal Engine's Gameplay Ability System (GAS) and adapted to Godot's strengths, it works well for ARPG, RTS, MOBA, and many other genres.

## Core Features

### Data-Driven Design
- Abilities, statuses, and effects are configured via resource files
- Build complex ability logic without writing code
- Supports runtime loading and modification

### Component Architecture
- **GameplayAbilityComponent**: Ability container — learn, activate, and cooldown
- **GameplayAttributeComponent**: Attribute management with modifiers and calculation
- **GameplayStatusComponent**: Buff/Debuff stacking and duration handling
- **GameplayVitalAttributeComponent**: Resource management (HP, MP, etc.)

### Behavior-Tree-Driven Ability Logic
- Describe ability execution flow with Behavior Trees
- Support complex combinations (combo, charge, toggle, etc.)
- Rich node types (wait, condition, parallel execution, etc.)

### Feature System
- Compose ability behavior by combining features
- Built-in features: cooldown, cost, input, toggle, passive status, and more
- Easy to extend with custom features

### Attribute System
- Attribute definitions, attribute sets, and attribute instances
- Attribute modifiers (temporary/permanent, stack/override)
- ScalableValue support for growth curves

### Status System
- Full Buff/Debuff system
- Stacking policies (refresh, stack, accumulate duration, etc.)
- Status features (periodic effects, event listeners, etc.)

### Effect System
- Rich gameplay effects (damage, heal, attribute modify, apply status, etc.)
- Effects can target attribute components, vital components, or character entities
- Supports effect chaining

### Tag System
- Tag-based classification and filtering
- Tag management for abilities, statuses, and effects
- Enables ability mutual exclusion, status immunity, and more

### Cue System
- Separates logic from presentation
- Supports particles, audio, animation, and other visual feedback
- Automatically manages cue lifecycle

## Quick Start

### Installation

#### Option 1: Git Submodule (Recommended)

```bash
git submodule add https://github.com/LiGameAcademy/godot_ability_system.git addons/godot_ability_system
```

#### Option 2: Clone Directly

```bash
git clone https://github.com/LiGameAcademy/godot_ability_system.git addons/godot_ability_system
```

### Enable the Plugin

1. Open the Godot editor
2. Go to `Project -> Project Settings -> Plugins`
3. Find `gameplay_abiltiy_system` and enable it

### Basic Usage

#### 1. Create a Character and Add Components

```gdscript
extends CharacterBody2D
class_name Player

@onready var ability_component: GameplayAbilityComponent = $GameplayAbilityComponent
@onready var attribute_component: GameplayAttributeComponent = $GameplayAttributeComponent
@onready var status_component: GameplayStatusComponent = $GameplayStatusComponent

func _ready() -> void:
	# Initialize attributes
	attribute_component.initialize_attribute_set(your_attribute_set)

	# Learn an ability
	ability_component.learn_ability(your_ability_definition)
```

#### 2. Create an Ability Definition

Create a `GameplayAbilityDefinition` resource in the editor:

1. Right-click in the FileSystem dock -> `New Resource`
2. Select `GameplayAbilityDefinition`
3. Configure ability properties (ID, name, icon, etc.)
4. Add features (cooldown, cost, etc.)
5. Create a behavior tree to define ability logic

#### 3. Activate an Ability

```gdscript
# Match by input
func _input(event: InputEvent) -> void:
	var ability_id = ability_component.match_input(event)
	if ability_id != "":
		ability_component.try_activate_ability(ability_id)

# Activate directly
ability_component.try_activate_ability(&"fireball")
```

## Architecture

### Core Concepts

```
Gameplay Layer (player, enemy, npc)
    ↓ via components
Plugin Layer
    ├── Component Layer
    │   ├── GameplayAbilityComponent
    │   ├── GameplayAttributeComponent
    │   ├── GameplayStatusComponent
    │   └── GameplayVitalAttributeComponent
    │
    ├── Instance Layer
    │   ├── GameplayAbilityInstance
    │   ├── GameplayAttributeInstance
    │   └── GameplayStatusInstance
    │
    ├── Resource Layer
    │   ├── GameplayAbilityDefinition
    │   ├── GameplayAttribute / AttributeSet
    │   ├── GameplayStatusData
    │   └── GameplayEffect
    │
    └── System Layer
        ├── GameplayAbilitySystem (singleton)
        ├── DamageCalculator (singleton)
        ├── TagManager (singleton)
        ├── AbilityEventBus (singleton)
        └── GameplayCueManager (singleton)
```

### Data Flow

1. **Resource Definition** → **Instantiate** → **Runtime Instance** → **Component Management** → **Attach to Character**
2. **Learn Ability** → **Activate Ability** → **Behavior Tree Execution** → **Apply Effects** → **Modify Status/Attributes**

For a detailed architecture diagram, see [docs/gameplay_ability_system.png](docs/gameplay_ability_system.png).

## Feature Modules

### Ability System

#### Ability Features

- ✅ Cooldown
- ✅ Cost
- ✅ Input
- ✅ Preview

#### Ability Templates

- ✅ Active Ability
- ✅ Passive Ability
- ✅ Toggle Ability
- ✅ Combo Ability
- ✅ Projectile Ability

### Attribute System

- ✅ Attribute definition and configuration
- ✅ Attribute Set
- ✅ Attribute Instance
- ✅ Attribute Modifier
- ✅ ScalableValue
- ✅ Attribute change notifications

### Status System

- ✅ Status data definition
- ✅ Status instance management
- ✅ Stacking policies
- ✅ Duration policies
- ✅ Status features (periodic effects, event listeners)
- ✅ Status priority

### Effect System

- ✅ Apply Damage
- ✅ Modify Vital (heal/damage resources)
- ✅ Attribute Modifier
- ✅ Apply Status
- ✅ Dispel Status
- ✅ Status Transform
- ✅ Spawn Magic Field
- ✅ Spawn Projectile

### Behavior Tree

- ✅ Composite nodes (Sequence, Selector, Parallel)
- ✅ Decorator nodes (Repeat, Wait, Condition)
- ✅ Action nodes (Play Animation, Apply Cost, Commit Cooldown)
- ✅ Wait Signal node
- ✅ Blackboard

### Other Systems

- ✅ Tag System
- ✅ Cue System
- ✅ Filter System
- ✅ Damage Calculator
- ✅ Event Bus

## Documentation

See the [docs/](docs/) directory for detailed docs:

- [Architecture](docs/architecture.md) — Overall architecture and design philosophy
- [Attribute System Guide](docs/attribute_system.md) — Configuring and using attributes
- [Effect System Guide](docs/effect_system.md) — Creating and applying effects
- [Status System Guide](docs/status_system.md) — Implementing and using statuses
- [Behavior Tree Guide](docs/behavior_tree.md) — Behavior trees and node reference
- [Ability System Guide](docs/ability_system.md) — Detailed ability usage guide
- [API Reference](docs/api_reference.md) — Full API documentation

## Design Principles

### 1. Data-Driven

Configure gameplay logic through resource files to reduce boilerplate and speed up iteration.

### 2. Component-Based

Use composition so feature modules stay independent, composable, and reusable.

### 3. Decoupled

Decouple systems via interfaces, signals, and an event bus to keep dependencies low.

### 4. Extensible

Provide extension points for custom features, effects, nodes, and more.

## Examples

The project includes several example scenes under `examples/`:

- `test_attribute.tscn` — Attribute system example
- `test_vital_system.tscn` — Vital/resource system example
- `test_status_component.tscn` — Status system example
- `test_effect_basic.tscn` — Effect system example

## Contributing

Issues and Pull Requests are welcome!

## License

This project is licensed under the [MIT License](LICENSE).

## Author

**Lao Li (玩物不丧志的老李)**

<a href="https://www.bilibili.com/cheese/play/ss791568227" target="_blank">
  <img src="https://archive.biliimg.com/bfs/archive/c16382c190d25495f8942cb10ce6582ed5b88c0e.jpg" alt="Bilibili Course">
</a>

- Course: [Godot 4 Architecture in Practice: Real-time Combat & Ability Systems](https://www.bilibili.com/cheese/play/ss791568227)
- Knowledge Planet: [Lao Li Game Academy](https://wx.zsxq.com/group/28885154818841)

## Acknowledgments

- Thanks to Unreal Engine's Gameplay Ability System for design inspiration
- Thanks to all contributors and users for their feedback

---

**Note**: This plugin is under active development. APIs may change. Please test thoroughly before using in production.
