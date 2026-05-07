#!/usr/bin/env python3
"""Генерирует PlantData + SeedData + YieldData для всех культур из таблицы."""
from __future__ import annotations

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# slug, ru_name, plant_type_en, rarity_en, base_price, yield_(min,max), grow_days, fruiting_days, water_every_days, id (a,b), traits, is_tall
PLANTS: list[tuple] = [
    ("carrot", "Морковь", "Vegetable", "Common", 10, (1, 3), 4, 0, 1, (1, 1), "", False),
    ("potato", "Картофель", "Vegetable", "Common", 3, (2, 5), 3, 0, 1, (2, 1), "", True),
    ("tomato", "Помидор", "Vegetable", "Uncommon", 7, (1, 2), 7, 3, 1, (2, 2), "", False),
    ("radish", "Редис", "Vegetable", "Uncommon", 20, (1, 2), 5, 0, 1, (1, 2), "", False),
    ("sunflower", "Подсолнух", "Flower", "Common", 2, (5, 10), 4, 0, 2, (2, 3), "", False),
    ("pea", "Горох", "Legume", "Uncommon", 1, (4, 8), 8, 3, 1, (1, 3), "", False),
    ("cabbage", "Капуста", "Vegetable", "Common", 15, (1, 1), 6, 0, 1, (1, 4), "", False),
    ("corn", "Кукуруза", "Grain", "Rare", 15, (2, 3), 4, 0, 1, (2, 4), "", False),
    ("bell_pepper", "Красный перец", "Vegetable", "Uncommon", 8, (1, 3), 6, 0, 1, (1, 5), "", False),
    ("watermelon", "Арбуз", "Berry", "Rare", 25, (1, 2), 9, 0, 1, (1, 6), "", False),
    ("eggplant", "Баклажан", "Vegetable", "Rare", 12, (1, 2), 8, 0, 1, (1, 7), "", False),
    ("melon", "Дыня", "Berry", "Rare", 18, (1, 2), 8, 0, 1, (1, 8), "", False),
    ("zucchini", "Кабачок", "Vegetable", "Common", 5, (2, 4), 5, 0, 1, (1, 9), "", False),
    ("raspberry", "Малина", "Berry", "Uncommon", 4, (3, 6), 6, 5, 1, (1, 10), "", False),
    ("strawberry", "Клубника", "Berry", "Uncommon", 3, (4, 8), 5, 4, 1, (1, 11), "", False),
    ("blueberry", "Черника", "Berry", "Uncommon", 6, (2, 5), 7, 3, 1, (1, 12), "", False),
    ("wheat", "Пшеница", "Grain", "Common", 2, (2, 4), 4, 0, 3, (2, 5), "", False),
    ("onion", "Репчатый лук", "Vegetable", "Common", 4, (1, 2), 4, 0, 1, (1, 13), "", False),
    ("green_onion", "Зелёный лук", "Vegetable", "Common", 3, (1, 3), 3, 0, 1, (1, 14), "", False),
    ("rose", "Роза", "Flower", "Rare", 12, (1, 3), 6, 0, 1, (2, 6), "", False),
    ("tulip", "Тюльпан", "Flower", "Common", 8, (1, 3), 4, 0, 1, (1, 15), "", False),
    ("orchid", "Орхидея", "Flower", "Rare", 35, (1, 2), 8, 0, 1, (1, 16), "", False),
    ("banana", "Банан", "Fruit", "Uncommon", 5, (2, 5), 10, 2, 1, (2, 7), "", False),
    ("pineapple", "Ананас", "Fruit", "Rare", 22, (1, 2), 9, 0, 1, (1, 17), "", False),
    ("peanut", "Арахис", "Legume", "Common", 4, (2, 4), 5, 0, 1, (1, 18), "", False),
    ("aloe", "Алоэ", "Herb", "Uncommon", 14, (1, 2), 6, 0, 1, (1, 19), "", False),
    ("plantain", "Подорожник", "Herb", "Common", 6, (1, 3), 4, 0, 1, (1, 20), "", False),
    ("bean", "Фасоль", "Legume", "Common", 2, (3, 6), 7, 0, 1, (1, 21), "", False),
    ("clover", "Клевер", "Legume", "Common", 1, (1, 3), 3, 0, 1, (1, 22), "Закон Мёрфи", False),
]


def write(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)


def plant_tres(
    *,
    slug: str,
    name: str,
    ptype: str,
    rarity: str,
    pid: tuple[int, int],
    row_y: int,
    grow: int,
    fruiting: int,
    water: int,
    yld: tuple[int, int],
    traits: str,
    tall: bool,
) -> str:
    ext_script = '[ext_resource type="Script" path="res://resources/plants/plant_data.gd" id="1"]\n'
    ext_potato = ""
    potato_res = ""
    if slug == "potato":
        ext_potato = '[ext_resource type="Script" path="res://resources/plants/potato.gd" id="pot"]\n'
        potato_res = "plant_script = ExtResource(\"pot\")\n"

    fx = "(32, 48)" if tall else "(32, 32)"
    tall_s = "true" if tall else "false"
    desc = f"{name}. {ptype}, {rarity}."
    if traits:
        desc += f" {traits}."

    return (
        f"[gd_resource type=\"Resource\" script_class=\"PlantData\" format=3]\n\n"
        f"{ext_script}{ext_potato}"
        f"[resource]\n"
        f"script = ExtResource(\"1\")\n"
        f"plant_id = Vector2i({pid[0]}, {pid[1]})\n"
        f"plant_name = \"{name}\"\n"
        f"plant_type = \"{ptype}\"\n"
        f"rarity = \"{rarity}\"\n"
        f"description = \"{desc}\"\n"
        f"plant_atlas_row_y = {row_y}\n"
        f"frame_px = Vector2i{fx}\n"
        f"is_tall = {tall_s}\n"
        f"grow_days = {grow}\n"
        f"days_of_fruiting = {fruiting}\n"
        f"water_every_days = {water}\n"
        f"yield_quantity = Vector2i({yld[0]}, {yld[1]})\n"
        f"special_traits = \"{traits}\"\n"
        f"{potato_res}"
    )


def seed_tres(
    *,
    slug: str,
    name: str,
    pid: tuple[int, int],
    icon: tuple[int, int],
) -> str:
    return (
        f"[gd_resource type=\"Resource\" script_class=\"SeedData\" format=3]\n\n"
        f"[ext_resource type=\"Script\" path=\"res://resources/items/seed_data.gd\" id=\"1\"]\n"
        f"[ext_resource type=\"Resource\" path=\"res://resources/plants/plants/{slug}.tres\" id=\"p\"]\n\n"
        f"[resource]\n"
        f"script = ExtResource(\"1\")\n"
        f"item_id = Vector2i({pid[0]}, {pid[1]})\n"
        f"icon_id = Vector2i({icon[0]}, {icon[1]})\n"
        f"item_name = \"Семена: {name}\"\n"
        f"description = \"Посадите на грядку.\"\n"
        f"item_type = 0\n"
        f"stack_size = 99\n"
        f"plant = ExtResource(\"p\")\n"
    )


def yield_tres(
    *,
    slug: str,
    name: str,
    pid: tuple[int, int],
    icon: tuple[int, int],
    price: int,
) -> str:
    return (
        f"[gd_resource type=\"Resource\" script_class=\"YieldData\" format=3]\n\n"
        f"[ext_resource type=\"Script\" path=\"res://resources/items/yield_data.gd\" id=\"1\"]\n"
        f"[ext_resource type=\"Resource\" path=\"res://resources/plants/plants/{slug}.tres\" id=\"p\"]\n\n"
        f"[resource]\n"
        f"script = ExtResource(\"1\")\n"
        f"item_id = Vector2i({pid[0]}, {pid[1]})\n"
        f"icon_id = Vector2i({icon[0]}, {icon[1]})\n"
        f"item_name = \"{name} (урожай)\"\n"
        f"description = \"Можно продать.\"\n"
        f"item_type = 1\n"
        f"stack_size = 999\n"
        f"base_price = {price}\n"
        f"plant = ExtResource(\"p\")\n"
    )


def plant_atlas_row_y(*, pid: tuple[int, int], tall: bool, idx: int) -> int:
    """Строка Y в атласе растений (1-based), как в Sprite.region_rect.

    Для id вида 1.N вторая координата plant_id — номер строки в short_plants_atlas.

    Для всего списка раньше брали (idx % 21) + 1: после нескольких культур «колонки 2», вставленных
    между 1.*, строка получалась примерно на число этих вставок больше N (типично +4 около 1.12).

    Колонку (2,*) кроме картофеля пока считаем по индексу в PLANTS, как было (до отдельного слоя PNG).
    Хвост списка 1.* (орхидея и ниже) %21 давал строки 1..8 заново и ломал id.
    """
    a, b = pid[0], pid[1]
    if a == 1:
        return b
    if tall:
        return min(b, 10)
    if idx >= 21:
        # После orchid только банан (2,7). %21 давал строку 1 как у моркови; залипаем на самую нижнюю строку.
        # Совпадает с 1.22 (клевер) пока короткий атлас только на 22 ряда.
        return 22
    return (idx % 21) + 1


def main() -> None:
    plants_dir = os.path.join(ROOT, "resources", "plants", "plants")
    seeds_dir = os.path.join(ROOT, "resources", "items", "seeds")
    yields_dir = os.path.join(ROOT, "resources", "items", "yields")

    for idx, row in enumerate(PLANTS):
        slug = row[0]
        ru = row[1]
        ptype = row[2]
        rarity = row[3]
        price = row[4]
        yld = row[5]
        grow = row[6]
        fruiting = row[7]
        water = row[8]
        pid = row[9]
        traits = row[10]
        tall = row[11]
        atlas_row = plant_atlas_row_y(pid=pid, tall=tall, idx=idx)

        iy = idx + 1
        ix_seed = 1
        ix_yield = 2
        if iy > 29:
            ix_seed = 1 + (iy // 29)
            iy = ((iy - 1) % 29) + 1

        p_path = os.path.join(plants_dir, f"{slug}.tres")
        write(p_path, plant_tres(
            slug=slug, name=ru, ptype=ptype, rarity=rarity, pid=pid,
            row_y=atlas_row, grow=grow, fruiting=fruiting, water=water,
            yld=yld, traits=traits, tall=tall,
        ))
        write(
            os.path.join(seeds_dir, f"{slug}_seed.tres"),
            seed_tres(slug=slug, name=ru, pid=pid, icon=(ix_seed, iy)),
        )
        write(
            os.path.join(yields_dir, f"{slug}_yield.tres"),
            yield_tres(slug=slug, name=ru, pid=pid, icon=(ix_yield, iy), price=price),
        )

    print(f"Written {len(PLANTS)} plants to {plants_dir}")


if __name__ == "__main__":
    main()
