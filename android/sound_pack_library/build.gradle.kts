// The library sound pack: 23 CC0 and public domain alarm sounds, delivered by
// Google Play only when the user asks for them. tools/sounds/library_pack.mjs
// writes src/main/assets. The id is permanent: the app asks Play for it by name.
plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName.set("sound_pack_library")
    dynamicDelivery {
        deliveryType.set("on-demand")
    }
}
