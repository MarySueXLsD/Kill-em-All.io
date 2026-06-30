require engine.core

module tile_texture_hint public

// Prefab-authored texture reference. Eden keeps this string in level.prefab.
// PrefabTextureHydrator copies texturePath -> SpriteRenderer.textureId at load.
class TileTextureHint : Component {
    texturePath : string = ""
}
