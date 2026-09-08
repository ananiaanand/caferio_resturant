/// One ingredient usage entry in a recipe.
class RecipeIngredientEntry {
  /// Matches [IngredientModel.id].
  final String ingredientId;

  /// Amount consumed per single serving (in the ingredient's base unit).
  final double amountPerServing;

  const RecipeIngredientEntry({
    required this.ingredientId,
    required this.amountPerServing,
  });
}

/// Full ingredient bill-of-materials for one dish.
class RecipeIngredientModel {
  /// Matches [Product.name] (used for lookup).
  final String dishName;

  final List<RecipeIngredientEntry> ingredients;

  const RecipeIngredientModel({
    required this.dishName,
    required this.ingredients,
  });
}

/// ─── Caferio Menu BOM Seed Data ─────────────────────────────────────────────
/// All amounts are in the ingredient's base unit (grams for solids, ml for liquids).
const List<RecipeIngredientModel> kRecipeBOM = [
  // ── Nadan Beef Roast ──────────────────────────────────────────────────────
  RecipeIngredientModel(
    dishName: 'Nadan Beef Roast',
    ingredients: [
      RecipeIngredientEntry(ingredientId: 'beef', amountPerServing: 250),
      RecipeIngredientEntry(ingredientId: 'onion_red', amountPerServing: 80),
      RecipeIngredientEntry(ingredientId: 'ginger', amountPerServing: 10),
      RecipeIngredientEntry(ingredientId: 'garlic', amountPerServing: 10),
      RecipeIngredientEntry(ingredientId: 'green_chili', amountPerServing: 5),
      RecipeIngredientEntry(ingredientId: 'curry_leaves', amountPerServing: 3),
      RecipeIngredientEntry(ingredientId: 'coconut_oil', amountPerServing: 20),
      RecipeIngredientEntry(ingredientId: 'turmeric', amountPerServing: 2),
      RecipeIngredientEntry(ingredientId: 'kashmiri_chili', amountPerServing: 5),
      RecipeIngredientEntry(ingredientId: 'coriander_powder', amountPerServing: 5),
      RecipeIngredientEntry(ingredientId: 'garam_masala', amountPerServing: 3),
      RecipeIngredientEntry(ingredientId: 'coconut_fresh', amountPerServing: 30),
    ],
  ),

  // ── Chicken Biryani ───────────────────────────────────────────────────────
  RecipeIngredientModel(
    dishName: 'Chicken Biryani',
    ingredients: [
      RecipeIngredientEntry(ingredientId: 'chicken_bone_in', amountPerServing: 300),
      RecipeIngredientEntry(ingredientId: 'basmati_rice', amountPerServing: 200),
      RecipeIngredientEntry(ingredientId: 'onion_red', amountPerServing: 100),
      RecipeIngredientEntry(ingredientId: 'yogurt', amountPerServing: 50),
      RecipeIngredientEntry(ingredientId: 'ghee', amountPerServing: 30),
      RecipeIngredientEntry(ingredientId: 'ginger', amountPerServing: 15),
      RecipeIngredientEntry(ingredientId: 'garlic', amountPerServing: 15),
      RecipeIngredientEntry(ingredientId: 'green_cardamom', amountPerServing: 2),
      RecipeIngredientEntry(ingredientId: 'cloves', amountPerServing: 2),
      RecipeIngredientEntry(ingredientId: 'cinnamon', amountPerServing: 3),
      RecipeIngredientEntry(ingredientId: 'bay_leaves', amountPerServing: 1),
      RecipeIngredientEntry(ingredientId: 'kasuri_methi', amountPerServing: 2),
      RecipeIngredientEntry(ingredientId: 'fresh_coriander', amountPerServing: 10),
    ],
  ),

  // ── Egg Fried Rice ────────────────────────────────────────────────────────
  RecipeIngredientModel(
    dishName: 'Egg Fried Rice',
    ingredients: [
      RecipeIngredientEntry(ingredientId: 'basmati_rice', amountPerServing: 180),
      RecipeIngredientEntry(ingredientId: 'eggs', amountPerServing: 2),
      RecipeIngredientEntry(ingredientId: 'spring_onion', amountPerServing: 20),
      RecipeIngredientEntry(ingredientId: 'capsicum', amountPerServing: 30),
      RecipeIngredientEntry(ingredientId: 'carrot', amountPerServing: 30),
      RecipeIngredientEntry(ingredientId: 'cabbage', amountPerServing: 40),
      RecipeIngredientEntry(ingredientId: 'dark_soy', amountPerServing: 15),
      RecipeIngredientEntry(ingredientId: 'sesame_oil', amountPerServing: 5),
      RecipeIngredientEntry(ingredientId: 'veg_oil', amountPerServing: 15),
      RecipeIngredientEntry(ingredientId: 'white_pepper', amountPerServing: 2),
      RecipeIngredientEntry(ingredientId: 'salt', amountPerServing: 3),
    ],
  ),

  // ── Gobi Manchurian ──────────────────────────────────────────────────────
  RecipeIngredientModel(
    dishName: 'Gobi Manchurian',
    ingredients: [
      RecipeIngredientEntry(ingredientId: 'cauliflower', amountPerServing: 200),
      RecipeIngredientEntry(ingredientId: 'cornflour', amountPerServing: 30),
      RecipeIngredientEntry(ingredientId: 'all_purpose_flour', amountPerServing: 20),
      RecipeIngredientEntry(ingredientId: 'ginger', amountPerServing: 8),
      RecipeIngredientEntry(ingredientId: 'garlic', amountPerServing: 8),
      RecipeIngredientEntry(ingredientId: 'capsicum', amountPerServing: 30),
      RecipeIngredientEntry(ingredientId: 'spring_onion', amountPerServing: 15),
      RecipeIngredientEntry(ingredientId: 'dark_soy', amountPerServing: 10),
      RecipeIngredientEntry(ingredientId: 'red_chili_sauce', amountPerServing: 15),
      RecipeIngredientEntry(ingredientId: 'veg_oil', amountPerServing: 30),
    ],
  ),

  // ── Kerala Parotta ────────────────────────────────────────────────────────
  RecipeIngredientModel(
    dishName: 'Kerala Parotta',
    ingredients: [
      RecipeIngredientEntry(ingredientId: 'all_purpose_flour', amountPerServing: 150),
      RecipeIngredientEntry(ingredientId: 'eggs', amountPerServing: 1),
      RecipeIngredientEntry(ingredientId: 'veg_oil', amountPerServing: 20),
      RecipeIngredientEntry(ingredientId: 'salt', amountPerServing: 2),
      RecipeIngredientEntry(ingredientId: 'sugar', amountPerServing: 5),
    ],
  ),

  // ── Chicken 65 ────────────────────────────────────────────────────────────
  RecipeIngredientModel(
    dishName: 'Chicken 65',
    ingredients: [
      RecipeIngredientEntry(ingredientId: 'chicken_boneless', amountPerServing: 220),
      RecipeIngredientEntry(ingredientId: 'yogurt', amountPerServing: 30),
      RecipeIngredientEntry(ingredientId: 'kashmiri_chili', amountPerServing: 8),
      RecipeIngredientEntry(ingredientId: 'turmeric', amountPerServing: 2),
      RecipeIngredientEntry(ingredientId: 'cornflour', amountPerServing: 20),
      RecipeIngredientEntry(ingredientId: 'curry_leaves', amountPerServing: 3),
      RecipeIngredientEntry(ingredientId: 'ginger', amountPerServing: 8),
      RecipeIngredientEntry(ingredientId: 'garlic', amountPerServing: 8),
      RecipeIngredientEntry(ingredientId: 'veg_oil', amountPerServing: 40),
      RecipeIngredientEntry(ingredientId: 'lemon', amountPerServing: 5),
    ],
  ),

  // ── Mutton Curry ─────────────────────────────────────────────────────────
  RecipeIngredientModel(
    dishName: 'Mutton Curry',
    ingredients: [
      RecipeIngredientEntry(ingredientId: 'mutton', amountPerServing: 280),
      RecipeIngredientEntry(ingredientId: 'onion_red', amountPerServing: 100),
      RecipeIngredientEntry(ingredientId: 'tomato_ketchup', amountPerServing: 20),
      RecipeIngredientEntry(ingredientId: 'ginger', amountPerServing: 12),
      RecipeIngredientEntry(ingredientId: 'garlic', amountPerServing: 12),
      RecipeIngredientEntry(ingredientId: 'coconut_oil', amountPerServing: 25),
      RecipeIngredientEntry(ingredientId: 'garam_masala', amountPerServing: 4),
      RecipeIngredientEntry(ingredientId: 'coriander_powder', amountPerServing: 6),
      RecipeIngredientEntry(ingredientId: 'turmeric', amountPerServing: 2),
      RecipeIngredientEntry(ingredientId: 'fresh_coriander', amountPerServing: 8),
    ],
  ),

  // ── Paneer Butter Masala ─────────────────────────────────────────────────
  RecipeIngredientModel(
    dishName: 'Paneer Butter Masala',
    ingredients: [
      RecipeIngredientEntry(ingredientId: 'paneer', amountPerServing: 200),
      RecipeIngredientEntry(ingredientId: 'onion_red', amountPerServing: 80),
      RecipeIngredientEntry(ingredientId: 'fresh_cream', amountPerServing: 50),
      RecipeIngredientEntry(ingredientId: 'butter', amountPerServing: 30),
      RecipeIngredientEntry(ingredientId: 'cashew', amountPerServing: 20),
      RecipeIngredientEntry(ingredientId: 'ginger', amountPerServing: 8),
      RecipeIngredientEntry(ingredientId: 'garlic', amountPerServing: 8),
      RecipeIngredientEntry(ingredientId: 'kashmiri_chili', amountPerServing: 5),
      RecipeIngredientEntry(ingredientId: 'garam_masala', amountPerServing: 3),
      RecipeIngredientEntry(ingredientId: 'kasuri_methi', amountPerServing: 2),
    ],
  ),
];
