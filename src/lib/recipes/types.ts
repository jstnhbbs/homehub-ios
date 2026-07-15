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
};

export type StoredRecipe = ParsedRecipe & {
  id: string;
  notes?: string | null;
  createdAt: Date;
  updatedAt: Date;
};
