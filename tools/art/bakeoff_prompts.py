#!/usr/bin/env python3
"""Prompt grammar used in the pose-anatomy bake-off (2026-11-28, MC test heroine).

Recipe components (see design/art_v6/BAKEOFF_VERDICT.md):
  IDENT   element tag + identity + outfit (OUTFIT_HEM is the recommended one)
  PROP_NEW  owner-binding proportion grammar (crotch line 45-48 %, leg <= torso + head)
  ANAT    anatomy + continuous-twist rules
  POSE[x] joint-by-joint pose text for the 6 test poses
  TAIL    style tail
  MANTXT  extra sentence when a pose-mannequin reference image is attached (V2)

build(pose, variant) -> prompt string. Variants:
  V0  old recipe (7.5 heads, long legs), one-line pose
  V1n ANAT + PROP_NEW + joint-by-joint pose (mini dress)
  V1o ANAT + OLD body line + joint-by-joint pose
  V1h V1n with OUTFIT_HEM (hem rule + moderate heels)  <- recommended
  V2  V1n + MANTXT (attach tools/art/pose_mannequin.py render as image_references)
"""
EL = "7df3cc78-06be-4080-87f0-49d3c1da4ff0"  # MC element
OUTFIT_OLD = ("Outfit: fitted black-and-gold qipao mini dress with gold dragon embroidery, bare shoulders, black lace detached sleeves, "
              "high side slits, sheer black thigh-high stockings with wide lace tops, black stiletto heels; the dress hem covers the hips. ")
OUTFIT_HEM = ("Outfit: fitted black-and-gold qipao dress with gold dragon embroidery, bare shoulders, black lace detached sleeves, "
              "an opaque skirt with the hem at mid-thigh and a modest side slit, sheer black thigh-high stockings with wide lace tops, "
              "black court heels of moderate height. HEM RULE: the opaque hem always stays in place and fully covers the buttocks from behind, "
              "from the side and in every pose; no bare skin of the buttocks is ever visible and the skin between hem and stocking tops is only the thigh. ")
HEAD = (f"<<<{EL}>>> is Mahjong-chan, an adult woman of 26, mahjong salon owner. Hair: light sakura-pink long glossy wavy hair in two high twin tails "
        "with long side strands, mint-jade looped knot hairpins with small pink cherry blossoms. Eyes: rose-pink. Skin: fair warm peach. "
        "Face: soft heart-shaped mature adult face. Items: jade drop earrings, white ruffled wrist cuffs with a mint band. ")
OLD = "Body: tall, soft and shapely, about 170 cm tall (7.5 heads tall), long legs with full soft thighs, wide rounded hips, a defined waist, a full bust. "
PROP_NEW = ("Proportions (binding): soft shapely mature figure, 6.85 heads tall (170 cm), a slightly larger head and shoulders, compact torso, balanced proportions: "
            "the crotch line sits at about 46% of her total height and her leg length from crotch to floor is no longer than her shoulder-to-crotch length plus one head; "
            "proportionate legs, soft full thighs with a visible knee and a tapering calf, wide rounded hips, a defined waist, a full bust. "
            "Portrait-lens camera (long focal length) at hip height, no wide-angle distortion, no from-below angle. ")
ANAT = ("ANATOMY RULES: exactly two arms and two legs, two hands with five fingers each, two feet; no duplicated, extra or fused limbs; both legs clearly separate and countable; "
        "thighs full and soft but anatomically proportional, a thigh is never wider than the pelvis at the hip line; knees and calves visible. "
        "The body twist is physically continuous: pelvis, buttocks and legs rotate together with the torso, the spine twists gradually through waist and ribcage and only the head and neck turn further. ")
TAIL = ("Glossy-warm painterly anime gacha key art, premium mobile-gacha quality, adult fashion pin-up styling, adult mature face and figure, confident teasing expression, "
        "lacquer-like highlights on hair, satin and sheer legwear, warm rim light, rich saturated colors, softened background, thin warm lineart with soft cel shading. "
        "Garments cover the chest, hips and groin and stay exactly in place. Full body in frame, one single character, no text, no letters, no logos, no watermark.")
SET = "Setting: softly blurred teahouse interior with paper lanterns, mint-jade tint. "
SIMPLE = {
 "a": "Pose: standing with her back to the camera, looking back over her shoulder at the viewer, one hand on her hip. ",
 "b": "Pose: leaning forward over a low tea table with both forearms on it, seen from behind and the side, glancing back at the viewer. ",
 "c": "Pose: seated on the edge of a mahjong table with her legs crossed, hands on the table edge. ",
 "d": "Pose: kneeling on a cushion arching her back, seen from the side and behind, looking back over her shoulder at the viewer. ",
 "e": "Pose: lying on her side on a chaise longue, hip raised, propped on one elbow. ",
 "f": "Pose: standing on one leg with the other leg lifted, hands in her hair. ",
}
POSE = {
 "a": "POSE, joint by joint: camera directly behind her at hip height. Her pelvis, buttocks and both legs face AWAY from the camera, so the REAR of her hips and thighs in the fitted dress is in view; the spine twists gradually at the waist and upper back so the shoulders turn about 45 degrees toward the camera and the head turns further, glancing back over her left shoulder with the face in three-quarter view looking at the viewer. Weight on the right leg, left knee slightly bent with the left heel lifted, hips tilted, gentle S-curve. Right hand rests on her right hip, left hand raised to touch the end of a twin tail. ",
 "b": "POSE, joint by joint: she stands behind a low lacquered tea table and leans forward from the hips about 60 degrees; camera behind her and slightly to her right side at hip height. Both legs nearly straight, feet shoulder-width apart, pelvis pushed back and up, lower back arched, the dress hem still covering the hips. Both forearms rest on the table with elbows bent. Her head turns back over her right shoulder toward the viewer with a teasing smile; the twist is continuous from the pelvis (rear in view) through the ribcage to the head. ",
 "c": "POSE, joint by joint: she sits on the edge of a mahjong table, torso upright facing the camera in three-quarter view. Right thigh crossed over the left thigh at the knee, right shin angled forward-down ending in a stiletto, left shin vertical ending in a stiletto, both feet clearly separate and visible, soft full thighs clearly separated where they cross. Both hands rest on the table edge beside her hips, shoulders relaxed, leaning back slightly. ",
 "d": "POSE, joint by joint: she kneels on a silk cushion, camera at her side and slightly behind at hip height. Knees hip-width apart on the cushion, shins flat on the floor pointing back, thighs near vertical; the pelvis is tilted so the hips are raised and pushed back, the lower back is deeply arched, chest lowered forward, both hands pressed flat on the cushion in front under her shoulders. Her face turns back over her shoulder to the viewer; hips and thighs are seen from the side-rear, continuous with the spine. ",
 "e": "POSE, joint by joint: she lies on her left side on a chaise longue; camera in front at about hip height. Left forearm on the cushion propping her upper body, head tilted toward the viewer. The waist dips and the upper hip rises as one smooth curve; legs stacked: lower leg extended, upper leg bent forward at the knee in front of it, both feet in stilettos, thighs full and soft. Right hand rests on her hip. ",
 "f": "POSE, joint by joint: camera in front at hip height. She stands on her left leg (straight, foot flat in a stiletto); her right knee is bent and lifted outward with the right foot raised behind her, heel toward the buttock; both hands raised to touch her twin tails, torso leaning back slightly, hips level, thighs proportionate. ",
}
MANTXT = ("Follow the body pose of the attached grey pose-mannequin reference image exactly (joint angles, facing direction, camera angle). It is a pose guide only: "
          "do not copy its grey color, flat background, props or shapes; the character keeps her own face, hair and outfit. A cross-in-circle on a body part means that part faces away "
          "from the camera, a dot-in-circle means it faces the camera, the green arrow shows where the head looks. ")


def build(pose, variant):
    if variant == "V0":
        return HEAD + OUTFIT_OLD + OLD + SIMPLE[pose] + SET + TAIL
    out = HEAD + (OUTFIT_HEM if variant == "V1h" else OUTFIT_OLD)
    out += (OLD if variant == "V1o" else PROP_NEW) + ANAT
    pose_txt = POSE[pose].replace("stiletto", "court heel") if variant == "V1h" else POSE[pose]
    out += pose_txt + SET + (MANTXT if variant == "V2" else "") + TAIL
    return out


if __name__ == "__main__":
    import sys
    print(build(sys.argv[1], sys.argv[2]))
