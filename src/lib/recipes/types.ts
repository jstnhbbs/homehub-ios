export type ParsedRecipe = {
  title: string;
  description?: string;
  servings?: string;
  prepTime?: string;
  cookTime?: string;
  totalTime?: string;
  ingredients: string[];
  directions: string[];
  nutrition?: Record<string, string>;
  imageUrl?: string;
  sourceUrl?: string;
  /** The page's own recipe categories ("Dinner", "Main Course"), used to suggest tags. */
  categories?: string[];
};

export type StoredRecipe = ParsedRecipe & {
  id: string;
  householdId: string;
  notes?: string | null;
  tags: string[];
  createdAt: Date;
  updatedAt: Date;
};
