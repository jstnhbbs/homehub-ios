const CATEGORY_RULES = [
  {
    category: "Produce",
    terms: ["apple", "banana", "berry", "lettuce", "tomato", "onion", "carrot"],
  },
  {
    category: "Dairy",
    terms: ["milk", "cheese", "yogurt", "butter", "cream", "eggs"],
  },
  {
    category: "Bakery",
    terms: ["bread", "bagel", "tortilla", "roll", "bun"],
  },
  {
    category: "Pantry",
    terms: ["pasta", "rice", "beans", "cereal", "flour", "sugar"],
  },
  {
    category: "Frozen",
    terms: ["frozen", "pizza", "waffle", "ice cream"],
  },
  {
    category: "Household",
    terms: ["soap", "paper", "detergent", "trash", "diaper", "wipes"],
  },
] as const;

export function categorizeShoppingItem(title: string) {
  const normalized = title.toLowerCase();
  return (
    CATEGORY_RULES.find((rule) =>
      rule.terms.some((term) => normalized.includes(term)),
    )?.category ?? "Other"
  );
}

export function parseShoppingTitle(raw: string) {
  const title = raw.trim().replace(/\s+/g, " ");
  const match = title.match(/^(\d+(?:\.\d+)?\s?(?:x|ct|lb|oz|gal|pk|pack)?)\s+(.+)/i);
  if (!match) {
    return { title, quantity: "" };
  }
  return { quantity: match[1], title: match[2] };
}

export function groupedShoppingItems<T extends { category: string }>(items: T[]) {
  return items.reduce<Map<string, T[]>>((groups, item) => {
    const group = groups.get(item.category) ?? [];
    group.push(item);
    groups.set(item.category, group);
    return groups;
  }, new Map<string, T[]>());
}
