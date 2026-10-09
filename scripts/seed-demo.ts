/**
 * Fills a demo household for App Store review (or a screenshot session): a made-up family with a
 * week or more of routines, chores, meals, recipes, groceries, notes, sleep logs and celebrations,
 * all dated relative to today.
 *
 *   DEMO_OWNER_EMAIL=... DEMO_OWNER_PASSWORD=... \
 *   DEMO_GUEST_EMAIL=... DEMO_GUEST_PASSWORD=... \
 *   npm run seed:demo            # the database in .env.local / the environment
 *   npm run seed:demo -- --yes   # required when that database is not a local file
 *
 * It creates the accounts if they don't exist (an existing account keeps its password) and
 * rebuilds their households from scratch every run, so run it again shortly before submitting to
 * refresh the dates. The owner is the only member of their household, so deleting that account (which
 * App Review may try) works; the guest belongs to a second, identical household run by a hidden owner
 * nobody signs in as. It never touches a household that has anyone else in it.
 */
import { randomBytes, randomUUID } from "node:crypto";
import { eq, inArray } from "drizzle-orm";
import { fromZonedTime } from "date-fns-tz";
import { db } from "@/db/client";
import * as s from "@/db/schema";
import { auth } from "@/lib/auth";
import { choreScheduleColumns } from "@/lib/chore-input";
import { chorePeriodKey } from "@/lib/chores";
import { localDateIn, weekKey } from "@/lib/dates";
import { categorizeGroceryItem, parseGroceryTitle } from "@/lib/groceries";
import { generateInviteCodePair } from "@/lib/invite-codes";
import { serializeSnackOptions } from "@/lib/meals/snacks";
import { PROFILE_COLORS } from "@/lib/profile-colors";
import { serializeRecipeFields } from "@/lib/recipes/store";
import { addDays } from "@/lib/streaks";

const TIMEZONE = process.env.DEMO_TIMEZONE ?? "America/Chicago";
const color = (label: string) => PROFILE_COLORS.find((entry) => entry.label === label)!.value;

function requireEnv(name: string) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Set ${name}.`);
  return value;
}

// MARK: Dates

const today = localDateIn(TIMEZONE);
const ago = (days: number) => addDays(today, -days);
const ahead = (days: number) => addDays(today, days);
const weekday = (date: string) => new Date(`${date}T12:00:00Z`).getUTCDay();
/** A moment on a local date, in the household's time zone. */
const at = (date: string, time: string) => fromZonedTime(`${date}T${time}:00`, TIMEZONE);
const now = new Date();
/** The same month and day as `date`, `years` years earlier. */
const yearsBefore = (date: string, years: number) => `${Number(date.slice(0, 4)) - years}${date.slice(4)}`;

// MARK: Accounts

async function ensureUser(name: string, email: string, password: string) {
  const [existing] = await db.select().from(s.users).where(eq(s.users.email, email.toLowerCase())).limit(1);
  if (existing) return { id: existing.id, created: false };
  const created = await auth.api.signUpEmail({ body: { name, email, password } });
  // Review shouldn't open on a "confirm your email" reminder for an address nobody can read.
  await db.update(s.users).set({ emailVerified: true }).where(eq(s.users.id, created.user.id));
  return { id: created.user.id, created: true };
}

/** Removes the households these accounts belong to, refusing if anyone else is in them. */
async function removeDemoHouseholds(userIds: string[]) {
  const memberships = await db.select().from(s.householdMembers).where(inArray(s.householdMembers.userId, userIds));
  for (const householdId of new Set(memberships.map((member) => member.householdId))) {
    const members = await db.select().from(s.householdMembers).where(eq(s.householdMembers.householdId, householdId));
    const stranger = members.find((member) => !userIds.includes(member.userId));
    if (stranger) {
      throw new Error(
        `Household ${householdId} has a member who isn't one of the demo accounts, so it was left alone. ` +
          "Check the DEMO_* email addresses.",
      );
    }
    await db.delete(s.households).where(eq(s.households.id, householdId));
  }
}

// MARK: Content

const SNACKS = ["Apple slices", "Cheese stick", "Fruit bars", "Yogurt", "Crackers", "Granola bar"];

const RECIPES: Array<{ title: string; description: string; servings: string; prepTime?: string; cookTime?: string; totalTime?: string; tags: string[]; ingredients: string[]; directions: string[]; nutrition: Record<string, string> }> = [
  {
    title: "Sheet Pan Chicken Fajitas",
    description: "Everything cooks on one pan, and the kids build their own.",
    servings: "4",
    prepTime: "15 min",
    cookTime: "25 min",
    totalTime: "40 min",
    tags: ["Dinner", "Chicken"],
    ingredients: [
      "## Fajitas",
      "1.5 lb chicken breast, sliced",
      "2 bell peppers, sliced",
      "1 onion, sliced",
      "2 tbsp olive oil",
      "2 tsp chili powder",
      "1 tsp cumin",
      "## To serve",
      "8 small flour tortillas",
      "Shredded cheese",
      "Sour cream",
      "Lime wedges",
    ],
    directions: [
      "Heat the oven to 425°F and line a sheet pan.",
      "Toss the chicken, peppers and onion with the oil and spices.",
      "Spread on the pan and roast 22 to 25 minutes, stirring once.",
      "Warm the tortillas and serve with the toppings.",
    ],
    nutrition: { Calories: "430 kcal", Protein: "38 g", Fat: "14 g", Carbohydrates: "34 g" },
  },
  {
    title: "Creamy Tomato Pasta",
    description: "A weeknight pasta that hides a lot of vegetables.",
    servings: "4",
    prepTime: "10 min",
    cookTime: "20 min",
    totalTime: "30 min",
    tags: ["Dinner", "Vegetarian"],
    ingredients: [
      "12 oz pasta",
      "1 can (28 oz) crushed tomatoes",
      "1 cup baby spinach",
      "1/2 cup cream",
      "2 cloves garlic, minced",
      "Parmesan, for serving",
    ],
    directions: [
      "Boil the pasta until just tender and save a cup of the water.",
      "Simmer the garlic and tomatoes for 10 minutes.",
      "Stir in the cream and spinach, then the pasta, loosening with pasta water.",
      "Top with Parmesan.",
    ],
    nutrition: { Calories: "510 kcal", Protein: "17 g", Fat: "16 g", Carbohydrates: "75 g" },
  },
  {
    title: "Blueberry Oat Pancakes",
    description: "Freezes well for school mornings.",
    servings: "12 pancakes",
    prepTime: "10 min",
    cookTime: "15 min",
    totalTime: "25 min",
    tags: ["Breakfast", "Vegetarian"],
    ingredients: ["1 1/2 cups oat flour", "1 tsp baking powder", "1 cup milk", "1 egg", "1 cup blueberries", "Maple syrup"],
    directions: [
      "Whisk the flour and baking powder, then the milk and egg.",
      "Fold in the blueberries.",
      "Cook 1/4 cup scoops on a hot greased pan until bubbles form, then flip.",
    ],
    nutrition: { Calories: "120 kcal", Protein: "4 g", Fat: "3 g", Carbohydrates: "19 g" },
  },
  {
    title: "Turkey & Cheese Roll-Ups",
    description: "A no-cook lunchbox filler.",
    servings: "2",
    prepTime: "5 min",
    totalTime: "5 min",
    tags: ["Lunch", "Turkey", "Snack"],
    ingredients: ["4 slices deli turkey", "4 slices cheese", "Cucumber sticks", "Grapes"],
    directions: ["Stack a slice of cheese on each slice of turkey and roll up.", "Pack with cucumber and grapes."],
    nutrition: { Calories: "210 kcal", Protein: "18 g" },
  },
  {
    title: "One-Pot Beef Chili",
    description: "Mild enough for the little ones; add hot sauce at the table.",
    servings: "6",
    prepTime: "15 min",
    cookTime: "45 min",
    totalTime: "1 hr",
    tags: ["Dinner", "Beef"],
    ingredients: [
      "## Chili",
      "1 lb ground beef",
      "1 onion, diced",
      "1 can kidney beans, drained",
      "1 can (15 oz) tomato sauce",
      "2 tbsp chili powder",
      "## Toppings",
      "Shredded cheese",
      "Sour cream",
      "Crackers",
    ],
    directions: [
      "Brown the beef with the onion and drain.",
      "Add the beans, tomato sauce, chili powder and a cup of water.",
      "Simmer 30 minutes, stirring now and then.",
    ],
    nutrition: { Calories: "380 kcal", Protein: "29 g", Fat: "17 g", Carbohydrates: "27 g" },
  },
  {
    title: "Banana Muffins",
    description: "A use for the bananas that turned.",
    servings: "12 muffins",
    prepTime: "10 min",
    cookTime: "20 min",
    totalTime: "30 min",
    tags: ["Breakfast", "Snack", "Dessert", "Vegetarian"],
    ingredients: ["3 ripe bananas", "1/3 cup melted butter", "3/4 cup sugar", "1 egg", "1 1/2 cups flour", "1 tsp baking soda"],
    directions: [
      "Heat the oven to 350°F and line a muffin tin.",
      "Mash the bananas and mix in the butter, sugar and egg.",
      "Stir in the flour and baking soda, fill the cups, and bake 20 minutes.",
    ],
    nutrition: { Calories: "190 kcal", Protein: "2 g", Fat: "6 g", Carbohydrates: "32 g" },
  },
  {
    title: "Baked Salmon with Rice",
    description: "Ready in the time it takes the rice to cook.",
    servings: "4",
    prepTime: "10 min",
    cookTime: "15 min",
    totalTime: "25 min",
    tags: ["Dinner", "Fish"],
    ingredients: ["4 salmon fillets", "1 tbsp olive oil", "1 lemon", "2 cups cooked rice", "Steamed broccoli"],
    directions: [
      "Heat the oven to 400°F.",
      "Rub the salmon with oil and lemon and bake 12 to 15 minutes.",
      "Serve over rice with broccoli.",
    ],
    nutrition: { Calories: "460 kcal", Protein: "34 g", Fat: "18 g", Carbohydrates: "38 g" },
  },
  {
    title: "Taco Night Bowls",
    description: "The same toppings as tacos without the shells breaking.",
    servings: "4",
    prepTime: "15 min",
    cookTime: "15 min",
    totalTime: "30 min",
    tags: ["Dinner", "Beef"],
    ingredients: ["1 lb ground beef", "1 packet taco seasoning", "2 cups rice", "Black beans", "Corn", "Shredded lettuce", "Salsa"],
    directions: [
      "Brown the beef and stir in the seasoning with a splash of water.",
      "Fill bowls with rice, beans, corn and beef.",
      "Add lettuce and salsa.",
    ],
    nutrition: { Calories: "520 kcal", Protein: "30 g", Fat: "19 g", Carbohydrates: "55 g" },
  },
];

// A week and a bit of meals, starting two days ago. `recipe` names a recipe above.
const MEAL_PLAN: Array<Partial<Record<"breakfast" | "lunch" | "dinner" | "snack", { title: string; recipe?: string }>>> = [
  { breakfast: { title: "Blueberry Oat Pancakes", recipe: "Blueberry Oat Pancakes" }, dinner: { title: "Taco Night Bowls", recipe: "Taco Night Bowls" } },
  { breakfast: { title: "Yogurt and fruit" }, lunch: { title: "Turkey & Cheese Roll-Ups", recipe: "Turkey & Cheese Roll-Ups" }, dinner: { title: "Creamy Tomato Pasta", recipe: "Creamy Tomato Pasta" } },
  { breakfast: { title: "Scrambled eggs and toast" }, lunch: { title: "Leftover pasta" }, dinner: { title: "Sheet Pan Chicken Fajitas", recipe: "Sheet Pan Chicken Fajitas" }, snack: { title: "Banana Muffins", recipe: "Banana Muffins" } },
  { breakfast: { title: "Oatmeal with berries" }, lunch: { title: "Grilled cheese and soup" }, dinner: { title: "One-Pot Beef Chili", recipe: "One-Pot Beef Chili" } },
  { breakfast: { title: "Banana Muffins", recipe: "Banana Muffins" }, dinner: { title: "Baked Salmon with Rice", recipe: "Baked Salmon with Rice" } },
  { breakfast: { title: "Waffles and strawberries" }, lunch: { title: "Picnic at the park" }, dinner: { title: "Homemade pizza night" } },
  { breakfast: { title: "Blueberry Oat Pancakes", recipe: "Blueberry Oat Pancakes" }, dinner: { title: "Leftover chili" } },
  { breakfast: { title: "Yogurt and granola" }, lunch: { title: "Turkey & Cheese Roll-Ups", recipe: "Turkey & Cheese Roll-Ups" }, dinner: { title: "Creamy Tomato Pasta", recipe: "Creamy Tomato Pasta" } },
  { dinner: { title: "Sheet Pan Chicken Fajitas", recipe: "Sheet Pan Chicken Fajitas" } },
];

const GROCERIES: Array<{ text: string; checked?: boolean }> = [
  { text: "Bananas" },
  { text: "Baby spinach" },
  { text: "2 lb chicken breast" },
  { text: "Whole milk" },
  { text: "Shredded cheese" },
  { text: "Greek yogurt" },
  { text: "Whole wheat tortillas" },
  { text: "Pasta" },
  { text: "Frozen peas" },
  { text: "Diapers", checked: true },
  { text: "Paper towels", checked: true },
  { text: "Blueberries", checked: true },
  { text: "Eggs" },
];

async function seedHousehold(input: { name: string; ownerId: string; ownerName: string; guest?: { id: string; name: string } }) {
  const householdId = randomUUID();
  const { inviteCode, guestInviteCode } = generateInviteCodePair();
  const reviewer = input.ownerId;

  await db.insert(s.households).values({
    id: householdId,
    name: input.name,
    timezone: TIMEZONE,
    weekStartsOn: 0,
    inviteCode,
    guestInviteCode,
    snackOptions: serializeSnackOptions(SNACKS),
    snacksPerChild: true,
  });
  await db.insert(s.householdMembers).values({ householdId, userId: input.ownerId, role: "owner" });
  if (input.guest) {
    await db.insert(s.householdMembers).values({ householdId, userId: input.guest.id, role: "guest" });
  }

  // People. The account holders get linked profiles, as joining does.
  const id = { owner: randomUUID(), sam: randomUUID(), guest: randomUUID(), maya: randomUUID(), leo: randomUUID(), nova: randomUUID() };
  const profile = (
    key: keyof typeof id,
    values: { name: string; type: "adult" | "child"; color: string; birthday?: string; userId?: string; sort: number },
  ) => ({
    id: id[key],
    householdId,
    userId: values.userId ?? null,
    profileType: values.type,
    name: values.name,
    color: values.color,
    birthday: values.birthday ?? null,
    sortOrder: values.sort,
  });
  await db.insert(s.profiles).values([
    profile("owner", { name: input.ownerName, type: "adult", color: color("Blue"), birthday: yearsBefore(ahead(90), 36), userId: input.ownerId, sort: -100 }),
    profile("sam", { name: "Sam Rivera", type: "adult", color: color("Plum"), birthday: yearsBefore(ahead(20), 35), sort: 0 }),
    profile("maya", { name: "Maya", type: "child", color: color("Coral"), birthday: yearsBefore(ahead(12), 7), sort: 1 }),
    profile("leo", { name: "Leo", type: "child", color: color("Gold"), birthday: yearsBefore(ahead(33), 4), sort: 2 }),
    profile("nova", { name: "Nova", type: "child", color: color("Teal"), birthday: ago(270), sort: 3 }),
    ...(input.guest
      ? [profile("guest", { name: input.guest.name, type: "adult", color: color("Olive"), userId: input.guest.id, sort: -99 })]
      : []),
  ]);

  // Routines, with a few weeks of history so the streaks and the check-offs have something to show.
  const routineDefs: Array<{ profile: string; name: string; period: "morning" | "afternoon" | "evening"; days: string; steps: string[]; skip: number[]; doneToday: number }> = [
    { profile: id.maya, name: "School Morning", period: "morning", days: "1,2,3,4,5", steps: ["Get dressed", "Eat breakfast", "Brush teeth", "Pack backpack"], skip: [5, 6, 12], doneToday: 2 },
    { profile: id.maya, name: "Bedtime", period: "evening", days: "0,1,2,3,4,5,6", steps: ["Bath", "Pajamas", "Read a book", "Lights out"], skip: [], doneToday: 0 },
    { profile: id.leo, name: "Morning Routine", period: "morning", days: "0,1,2,3,4,5,6", steps: ["Get dressed", "Brush teeth", "Make bed"], skip: [3, 9], doneToday: 1 },
    { profile: id.leo, name: "After Preschool", period: "afternoon", days: "1,2,3,4,5", steps: ["Wash hands", "Snack", "Quiet play"], skip: [2], doneToday: 0 },
  ];
  const stepCreated = at(ago(30), "09:00");
  const routineRows: (typeof s.routines.$inferInsert)[] = [];
  const stepRows: (typeof s.routineSteps.$inferInsert)[] = [];
  const completionRows: (typeof s.routineCompletions.$inferInsert)[] = [];
  routineDefs.forEach((def, routineIndex) => {
    const routineId = randomUUID();
    routineRows.push({ id: routineId, householdId, profileId: def.profile, name: def.name, period: def.period, days: def.days, sortOrder: routineIndex });
    def.steps.forEach((label, stepIndex) => {
      const stepId = randomUUID();
      stepRows.push({ id: stepId, routineId, label, sortOrder: stepIndex, createdAt: stepCreated });
      for (let back = 1; back <= 21; back += 1) {
        const date = ago(back);
        if (!def.days.split(",").includes(String(weekday(date))) || def.skip.includes(back)) continue;
        completionRows.push({ stepId, localDate: date, completedAt: at(date, "07:45"), completedBy: reviewer });
      }
      if (stepIndex < def.doneToday && def.days.split(",").includes(String(weekday(today)))) {
        completionRows.push({ stepId, localDate: today, completedAt: now, completedBy: reviewer });
      }
    });
  });
  await db.insert(s.routines).values(routineRows);
  await db.insert(s.routineSteps).values(stepRows);
  await db.insert(s.routineCompletions).values(completionRows).onConflictDoNothing();

  // Chores, covering every kind of repeat the app offers.
  const choreDefs: Array<{ title: string; profile: string; input: Parameters<typeof choreScheduleColumns>[0]; doneToday?: boolean }> = [
    { title: "Feed the dog", profile: id.maya, input: { title: "", repeatUnit: "day" }, doneToday: true },
    { title: "Set the table", profile: id.maya, input: { title: "", repeatUnit: "day" } },
    { title: "Water the plants", profile: id.maya, input: { title: "", repeatUnit: "week", weekDay: "6" } },
    { title: "Put toys away", profile: id.leo, input: { title: "", repeatUnit: "day" } },
    { title: "Evening dog walk", profile: id.owner, input: { title: "", repeatUnit: "day", dueTime: "18:30" } },
    { title: "Take out the trash", profile: id.owner, input: { title: "", repeatUnit: "week", weekDay: String(weekday(ahead(1))) as "0" | "1" | "2" | "3" | "4" | "5" | "6" } },
    { title: "Pay the water bill", profile: id.sam, input: { title: "", repeatUnit: "month", dueDate: ahead(9) } },
    { title: "Change the air filter", profile: id.owner, input: { title: "", repeatUnit: "month", repeatInterval: 3, dueDate: ago(20) } },
    { title: "Grocery pickup", profile: id.sam, input: { title: "", repeatUnit: "none", dueDate: ahead(2), dueTime: "17:30" } },
    { title: "Call the pediatrician", profile: id.sam, input: { title: "", repeatUnit: "none" } },
  ];
  const choreRows = choreDefs.map((def, index) => {
    const columns = choreScheduleColumns(def.input);
    return { id: randomUUID(), householdId, profileId: def.profile, title: def.title, sortOrder: index, ...columns };
  });
  await db.insert(s.chores).values(choreRows);
  const choreCompletions = choreDefs.flatMap((def, index) =>
    def.doneToday
      ? [{ choreId: choreRows[index].id, periodKey: chorePeriodKey(choreRows[index], today), completedAt: now, completedBy: reviewer }]
      : [],
  );
  const waterPlants = choreRows[2];
  choreCompletions.push({ choreId: waterPlants.id, periodKey: weekKey(new Date(`${ago(3)}T12:00:00`)), completedAt: at(ago(3), "10:00"), completedBy: reviewer });
  await db.insert(s.choreCompletions).values(choreCompletions).onConflictDoNothing();

  // Recipes and the meal plan.
  const recipeIds = new Map<string, string>();
  await db.insert(s.recipes).values(
    RECIPES.map((recipe) => {
      const recipeId = randomUUID();
      recipeIds.set(recipe.title, recipeId);
      const fields = serializeRecipeFields({ ingredients: recipe.ingredients, directions: recipe.directions, nutrition: recipe.nutrition, tags: recipe.tags });
      return {
        id: recipeId,
        householdId,
        title: recipe.title,
        description: recipe.description,
        servings: recipe.servings,
        prepTime: recipe.prepTime ?? null,
        cookTime: recipe.cookTime ?? null,
        totalTime: recipe.totalTime ?? null,
        ...fields,
      };
    }),
  );
  const mealRows: (typeof s.meals.$inferInsert)[] = [];
  MEAL_PLAN.forEach((day, offset) => {
    for (const [slot, meal] of Object.entries(day) as Array<[keyof typeof day, { title: string; recipe?: string }]>) {
      mealRows.push({
        id: randomUUID(),
        householdId,
        localDate: ago(2 - offset),
        slot,
        title: meal.title,
        recipeId: meal.recipe ? (recipeIds.get(meal.recipe) ?? null) : null,
      });
    }
  });
  await db.insert(s.meals).values(mealRows);

  // Groceries, snacks, notes.
  await db.insert(s.groceryItems).values(
    GROCERIES.map((item, index) => {
      const parsed = parseGroceryTitle(item.text);
      return {
        id: randomUUID(),
        householdId,
        title: parsed.title,
        quantity: parsed.quantity,
        category: categorizeGroceryItem(parsed.title),
        checked: Boolean(item.checked),
        checkedAt: item.checked ? now : null,
        sortOrder: index,
      };
    }),
  );
  const snackRow = (date: string, snackLabel: string, profileId: string) => ({ householdId, localDate: date, snackLabel, profileId, completedAt: at(date, "15:30") });
  await db.insert(s.snackCompletions).values([
    // Nova counts as a child too, so a snack only reads as eaten once all three have had it.
    snackRow(today, "Apple slices", id.maya),
    snackRow(today, "Apple slices", id.leo),
    snackRow(today, "Apple slices", id.nova),
    snackRow(today, "Yogurt", id.maya),
    snackRow(ago(1), "Cheese stick", id.maya),
    snackRow(ago(1), "Cheese stick", id.leo),
    snackRow(ago(1), "Cheese stick", id.nova),
    snackRow(ago(1), "Fruit bars", id.leo),
    snackRow(ago(1), "Granola bar", id.maya),
  ]);
  const author = input.guest?.id ?? input.ownerId;
  await db.insert(s.householdNotes).values([
    { id: randomUUID(), householdId, createdByUserId: input.ownerId, title: "Picture day is Friday", body: "Maya wears the blue dress. Leo's is next week.", pinned: true },
    { id: randomUUID(), householdId, createdByUserId: input.ownerId, title: "Pediatrician Thursday 3:30", body: "Nova's 9-month checkup. Bring the vaccine record.", pinned: true },
    { id: randomUUID(), householdId, createdByUserId: author, title: "Babysitter notes", body: "Leo's bedtime is 7:30. Nova takes a bottle at 6. Emergency numbers are on the fridge.", pinned: false },
    { id: randomUUID(), householdId, createdByUserId: input.ownerId, title: "Gift ideas for Grandma", body: "A photo book of the kids, garden gloves, tulip bulbs.", pinned: false },
  ]);

  // Sleep: all three children sleep at night, Nova naps three times a day and Leo once.
  const sleepRows: (typeof s.napLogs.$inferInsert)[] = [];
  const addSleep = (profileId: string, kind: "nap" | "night", date: string, from: Date, to: Date, notes?: string) => {
    if (to > now) return;
    sleepRows.push({ id: randomUUID(), householdId, profileId, kind, localDate: date, startedAt: from, endedAt: to, notes: notes ?? null });
  };
  for (let back = 0; back <= 6; back += 1) {
    const date = ago(back);
    addSleep(id.nova, "nap", date, at(date, "09:10"), at(date, "10:05"));
    addSleep(id.nova, "nap", date, at(date, "12:40"), at(date, "14:10"), back === 1 ? "Slept in the car seat" : undefined);
    addSleep(id.nova, "nap", date, at(date, "16:30"), at(date, "17:00"));
    addSleep(id.nova, "night", date, at(ago(back + 1), "19:20"), at(date, "05:50"));
    addSleep(id.leo, "night", date, at(ago(back + 1), "19:45"), at(date, "06:40"));
    addSleep(id.maya, "night", date, at(ago(back + 1), "20:15"), at(date, "06:30"));
    if (back <= 5) addSleep(id.leo, "nap", date, at(date, "13:00"), at(date, "14:15"));
  }
  await db.insert(s.napLogs).values(sleepRows);

  // Celebrations that aren't household members, so the Celebrations page has anniversaries too.
  await db.insert(s.familyBirthdays).values([
    { id: randomUUID(), householdId, name: "Grandma Rosa", birthDate: yearsBefore(ahead(8), 68), kind: "birthday", giftIdeas: "Photo book of the kids; garden gloves", notifyDaysBefore: 7 },
    { id: randomUUID(), householdId, name: "Uncle Dan", birthDate: yearsBefore(ahead(40), 41), kind: "birthday", notifyDaysBefore: 3 },
    { id: randomUUID(), householdId, name: "Alex & Sam", birthDate: yearsBefore(ahead(25), 11), kind: "anniversary", notes: "Dinner reservation at 7", notifyDaysBefore: 7 },
  ]);

  return { householdId, inviteCode, guestInviteCode };
}

// MARK: Run

async function main() {
  const url = process.env.TURSO_DATABASE_URL ?? "file:local.db";
  const isFile = url.startsWith("file:");
  console.log(`Database: ${isFile ? url : new URL(url.replace(/^libsql:/, "https:")).host}`);
  if (!isFile && !process.argv.includes("--yes")) {
    throw new Error("That is not a local database. Run again with --yes to seed it.");
  }

  const ownerEmail = requireEnv("DEMO_OWNER_EMAIL");
  const ownerPassword = requireEnv("DEMO_OWNER_PASSWORD");
  const guestEmail = requireEnv("DEMO_GUEST_EMAIL");
  const guestPassword = requireEnv("DEMO_GUEST_PASSWORD");
  for (const password of [ownerPassword, guestPassword]) {
    if (password.length < 10) throw new Error("Passwords need at least 10 characters.");
  }
  if (ownerEmail.toLowerCase() === guestEmail.toLowerCase()) throw new Error("Use two different email addresses.");

  const owner = await ensureUser("Alex Rivera", ownerEmail, ownerPassword);
  const guest = await ensureUser("Pat Taylor", guestEmail, guestPassword);
  // The guest household needs an owner nobody signs in as: a throwaway password nobody is told.
  const hostEmail = process.env.DEMO_GUEST_HOST_EMAIL ?? `demo-host-${guestEmail.toLowerCase().replace(/[^a-z0-9]/g, "")}@example.com`;
  const host = await ensureUser("Jamie Rivera", hostEmail, randomBytes(18).toString("base64url"));

  await removeDemoHouseholds([owner.id, guest.id, host.id]);
  const primary = await seedHousehold({ name: "The Rivera Family", ownerId: owner.id, ownerName: "Alex Rivera" });
  await seedHousehold({ name: "The Rivera Family (guest view)", ownerId: host.id, ownerName: "Jamie Rivera", guest: { id: guest.id, name: "Pat Taylor" } });

  console.log("");
  console.log(`Owner account  ${ownerEmail}  (${owner.created ? "created" : "already existed; password unchanged"})`);
  console.log(`Guest account  ${guestEmail}  (${guest.created ? "created" : "already existed; password unchanged"})`);
  console.log(`Owner household invite codes (not needed for review): parent ${primary.inviteCode}, guest ${primary.guestInviteCode}`);
  console.log(`Dates are relative to ${today} (${TIMEZONE}). Run again shortly before submitting to refresh them.`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exit(1);
  });
