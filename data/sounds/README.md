# Client sounds

Keep one folder per client version. The game loads `/sounds/<version>/`.

```
data/sounds/
  README.md
  1530/
    catalog-sound.json
    sounds-….dat          # soundbank (protobuf), required
    sound-….ogg           # audio files listed by the soundbank
```

`1524` and loose files in the sounds root are obsolete. Do not put `.ogg` files directly under `data/sounds/`.
