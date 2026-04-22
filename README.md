# Idle Dot Shooter — Godot 4 Project

## Project Structure

```
idle_dot_shooter/
├── project.godot
├── main.tscn              ← Root scene, wire this up first
├── main.gd
│
├── components/            ← Reusable component nodes (attach to anything)
│   ├── HealthComponent.gd
│   ├── DamageComponent.gd
│   ├── DriftComponent.gd
│   └── ShooterComponent.gd
│
├── entities/
│   ├── turret/
│   │   ├── Turret.tscn
│   │   └── turret.gd
│   ├── bullet/
│   │   ├── Bullet.tscn
│   │   └── bullet.gd
│   └── dot/
│       ├── Dot.tscn
│       └── dot.gd
│
├── audio/
│   └── AudioManager.gd    ← Autoload singleton
│
└── ui/
	├── HUD.tscn
	└── hud.gd
```

## Scene Setup Guide

### 1. Autoload (Project > Project Settings > Autoload)
- Add `audio/AudioManager.gd` as `AudioManager`

### 2. main.tscn node tree
```
Node2D (main.gd)  [group: "main"]
├── Turret (instance Turret.tscn)
│   └── position: center of screen e.g. (576, 324) for 1152x648
└── HUD (instance HUD.tscn)
```

### 3. Turret.tscn node tree
```
Node2D (turret.gd)
├── Polygon2D              ← triangle shape, drawn in _draw or via points
├── ShooterComponent       ← attach ShooterComponent.gd
└── AudioStreamPlayer      ← name it "ShootSound", handled by AudioManager
```

### 4. Bullet.tscn node tree
```
Area2D (bullet.gd)
├── CollisionShape2D       ← CircleShape2D, radius 5
├── DamageComponent        ← attach DamageComponent.gd
└── Polygon2D              ← small white circle visual
```

### 5. Dot.tscn node tree
```
Area2D (dot.gd)
├── CollisionShape2D       ← CircleShape2D, radius 16
├── HealthComponent        ← attach HealthComponent.gd
├── DriftComponent         ← attach DriftComponent.gd
└── Polygon2D              ← colored circle visual
```

### 6. HUD.tscn node tree
```
CanvasLayer (hud.gd)
└── VBoxContainer
	├── Label (name: CurrencyLabel)
	└── Label (name: DotsLabel)
```

## Collision Layers
| Layer | Purpose        |
|-------|----------------|
| 1     | Dots           |
| 2     | Bullets        |

- Dots: Layer 1, Mask 2
- Bullets: Layer 2, Mask 1

## Audio
All sounds are procedurally generated — no audio files needed.
AudioManager is an Autoload. Call it from anywhere:
```gdscript
AudioManager.play_shoot()
AudioManager.play_hit()
AudioManager.play_pop()
```
