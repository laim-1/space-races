# Space Races — Development Notes

## After every significant change

1. Open the project in Godot 4: `File → Open Project` → select `godot/`
2. Export to web: `Project → Export → Web → Export Project`
   - Output path is already set to `../docs/index.html`
3. Commit and push:
   ```
   git add -A
   git commit -m "feat: <describe change>"
   git push -u origin <branch>
   ```
4. GitHub Pages will auto-deploy from the `docs/` folder on the `main` branch.

## GitHub Pages setup (one-time)

1. Go to **Settings → Pages** in the GitHub repo
2. Under **Source**, choose **Deploy from a branch**
3. Set branch to `main`, folder to `/docs`
4. Click **Save** — the site will be live at `https://<user>.github.io/space-races/`

## Project structure

```
godot/               Godot 4 project
  project.godot      Main config — entry scene: scenes/Main.tscn
  scenes/
    Main.tscn        Root scene (spawns all other nodes)
    Fighter.tscn     CharacterBody3D fighter prefab
    Arena.tscn       Procedural octagon arena
    ui/HUD.tscn      CanvasLayer HUD
  scripts/
    Main.gd          Game loop, spawning, signal routing
    Fighter.gd       Fighter AI, state machine, combat
    Arena.gd         Procedural arena geometry
    CameraRig.gd     Follow camera + screen shake
    HUD.gd           Health bars, kill feed, combo, results
  export_presets.cfg Web export target → ../docs/index.html
docs/                GitHub Pages root
  index.html         Exported Godot web build (overwritten on export)
  .nojekyll          Required for Godot web exports on GitHub Pages
index.html           Original JS/Canvas prototype (kept for reference)
```

## Fighter 3D model swap

When you have your 3D model files ready:

1. Add the `.glb`/`.gltf` to `godot/assets/models/`
2. Open `Fighter.tscn`, replace the `MeshInstance3D` (CapsuleMesh) with your imported model node
3. Keep `GlowRing`, `CollisionShape3D`, `NameLabel`, and `AttackHitbox` nodes as-is
4. The `Fighter.gd` script references `$MeshInstance3D` — rename your model node to match, or update the script variable
