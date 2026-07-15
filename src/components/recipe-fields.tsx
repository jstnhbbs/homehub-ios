export function RecipeFields({
  defaults = {},
}: {
  defaults?: Partial<{
    title: string;
    description: string;
    servings: string;
    prepTime: string;
    cookTime: string;
    totalTime: string;
    ingredients: string;
    directions: string;
    nutrition: string;
    sourceUrl: string;
    imageUrl: string;
    notes: string;
  }>;
}) {
  return (
    <>
      <input
        name="title"
        className="hub-input"
        placeholder="Recipe title"
        defaultValue={defaults.title}
        required
      />
      <textarea
        name="description"
        className="hub-input min-h-20 resize-none"
        placeholder="Short description (optional)"
        defaultValue={defaults.description}
      />
      <div className="grid grid-cols-2 gap-2">
        <input
          name="servings"
          className="hub-input"
          placeholder="Servings"
          defaultValue={defaults.servings}
        />
        <input
          name="totalTime"
          className="hub-input"
          placeholder="Total time"
          defaultValue={defaults.totalTime}
        />
        <input
          name="prepTime"
          className="hub-input"
          placeholder="Prep time"
          defaultValue={defaults.prepTime}
        />
        <input
          name="cookTime"
          className="hub-input"
          placeholder="Cook time"
          defaultValue={defaults.cookTime}
        />
      </div>
      <label className="block">
        <span className="mb-1 block text-xs font-bold">Ingredients</span>
        <textarea
          name="ingredients"
          className="hub-input min-h-32 resize-none font-mono text-sm"
          placeholder={"1 cup flour\n2 eggs"}
          defaultValue={defaults.ingredients}
          required
        />
      </label>
      <label className="block">
        <span className="mb-1 block text-xs font-bold">Directions</span>
        <textarea
          name="directions"
          className="hub-input min-h-36 resize-none"
          placeholder={"Preheat the oven.\nMix and bake."}
          defaultValue={defaults.directions}
          required
        />
      </label>
      <label className="block">
        <span className="mb-1 block text-xs font-bold">Nutrition</span>
        <textarea
          name="nutrition"
          className="hub-input min-h-24 resize-none font-mono text-sm"
          placeholder={"Calories: 420\nProtein: 24 g"}
          defaultValue={defaults.nutrition}
        />
      </label>
      <input
        name="sourceUrl"
        className="hub-input"
        placeholder="Source URL (optional)"
        defaultValue={defaults.sourceUrl}
      />
      <input
        name="imageUrl"
        className="hub-input"
        placeholder="Image URL (optional)"
        defaultValue={defaults.imageUrl}
      />
      <textarea
        name="notes"
        className="hub-input min-h-20 resize-none"
        placeholder="Family notes (optional)"
        defaultValue={defaults.notes}
      />
    </>
  );
}
