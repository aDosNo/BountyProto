#!/usr/bin/env python3
"""Validate Hesperus Market layout data against the locked layout document."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path
from typing import Any


REQUIRED_SECTION_IDS = [
    "S1_DOCK_BAY",
    "S2_BOUNTY_BOARD_HUB",
    "S3_SIDE_ALLEY",
    "S4_MAIN_BAZAAR_STREET",
    "S5_UPPER_WALKWAY_OVERLAY",
    "S6_CAPTURE_COURTYARD",
    "S7_RETURN_UTILITY_STRIP",
]

ROUTE_COLOR_LANGUAGE = {
    "green": "extraction / return",
    "yellow": "bounty / interactable",
    "blue": "clue / investigation",
    "purple": "upper walkway / elevated traversal",
    "orange": "utility / crawl / vent",
    "red": "target / capture / danger",
}

APPROVED_S7_PORT_LAYERS = {"return", "utility"}
ADJACENCY_TOLERANCE_METERS = 0.5


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def parse_json_blocks(markdown: str) -> list[dict[str, Any]]:
    blocks = re.findall(r"```json\n(.*?)\n```", markdown, re.DOTALL)
    return [json.loads(block) for block in blocks]


def normalize_label(value: str) -> str:
    value = value.replace("—", "-").replace("/", " ")
    value = re.sub(r"^Section\s+\d+\s*(?:-\s*)?", "", value)
    value = re.sub(r"[^A-Za-z0-9]+", "_", value)
    return value.strip("_").upper()


def parse_route_color_language(markdown: str) -> dict[str, str]:
    match = re.search(r"## Route Color Language\n\n(?P<body>.*?)(?:\n## |\n---)", markdown, re.DOTALL)
    if not match:
        raise ValueError("Could not find Route Color Language section in locked layout doc.")

    colors: dict[str, str] = {}
    for color, meaning in re.findall(r"-\s+([A-Za-z]+)\s+=\s+(.+)", match.group("body")):
        colors[color.lower()] = meaning.strip()
    return colors


def parse_required_sections(markdown: str) -> list[str]:
    match = re.search(
        r"# 2\. Locked Sections.*?There are exactly seven locked sections:\n\n(?P<body>.*?)\n\nNo additional",
        markdown,
        re.DOTALL,
    )
    if not match:
        raise ValueError("Could not find locked section list in locked layout doc.")
    return re.findall(r"`([^`]+)`", match.group("body"))


def parse_section_contract(markdown: str, section_ids: list[str]) -> dict[str, dict[str, Any]]:
    label_to_id: dict[str, str] = {}
    for index, section_id in enumerate(section_ids, start=1):
        suffix = section_id.split("_", 1)[1]
        label_to_id[normalize_label(f"Section {index} - {suffix.replace('_', ' ').title()}")] = section_id

    body_match = re.search(r"# 3\. Locked Global Placement\n\n(?P<body>.*?)\n---", markdown, re.DOTALL)
    if not body_match:
        raise ValueError("Could not find Locked Global Placement section in locked layout doc.")

    sections: dict[str, dict[str, Any]] = {}
    section_blocks = re.findall(
        r"## Section \d+ .+?\n\n(?P<body>.*?)(?=\n## Section \d+ |\Z)",
        body_match.group("body"),
        re.DOTALL,
    )

    for index, block in enumerate(section_blocks):
        section_id = section_ids[index]
        purpose_match = re.search(r"- Purpose:\s*(.+)", block)
        if not purpose_match:
            raise ValueError(f"Missing Purpose line for {section_id}.")

        position_match = re.search(r"- Position:\s*(.+)", block)
        neighbors_match = re.search(r"- Direct neighbors:\n(?P<body>(?:\s+- .+\n?)+)", block)
        if not neighbors_match:
            raise ValueError(f"Missing Direct neighbors list for {section_id}.")

        neighbors: list[str] = []
        for label in re.findall(r"\s+-\s+(.+)", neighbors_match.group("body")):
            normalized = normalize_label(label)
            if normalized not in label_to_id:
                raise ValueError(f"Could not resolve neighbor '{label}' for {section_id}.")
            neighbors.append(label_to_id[normalized])

        purpose = purpose_match.group(1).strip()
        landmarks = [part.strip().rstrip(".") for part in re.split(r",|\sand\s", purpose) if part.strip()]

        sections[section_id] = {
            "position_summary": position_match.group(1).strip() if position_match else "",
            "purpose": purpose,
            "direct_neighbors": neighbors,
            "required_landmarks": landmarks,
        }

    if set(sections) != set(section_ids):
        raise ValueError("Global placement section count does not match locked section IDs.")

    return sections


def contract_from_doc(doc_path: Path) -> dict[str, Any]:
    markdown = doc_path.read_text(encoding="utf-8")
    json_blocks = parse_json_blocks(markdown)
    if len(json_blocks) < 2:
        raise ValueError("Expected section-bounds and port JSON blocks in locked layout doc.")

    section_ids = parse_required_sections(markdown)
    return {
        "route_color_language": parse_route_color_language(markdown),
        "section_ids": section_ids,
        "section_bounds": json_blocks[0]["sections"],
        "section_placement": parse_section_contract(markdown, section_ids),
        "ports": json_blocks[1]["ports"],
    }


def same_keys(actual: dict[str, Any], expected_ids: list[str], label: str, errors: list[str]) -> None:
    actual_ids = set(actual)
    expected = set(expected_ids)
    for missing in sorted(expected - actual_ids):
        errors.append(f"Missing {label}: {missing}")
    for extra in sorted(actual_ids - expected):
        errors.append(f"Unapproved extra {label}: {extra}")


def compare_value(path: str, actual: Any, expected: Any, errors: list[str]) -> None:
    if actual != expected:
        errors.append(f"{path} mismatch: expected {expected!r}, got {actual!r}")


def compare_position(path: str, actual: dict[str, Any], expected: dict[str, Any], errors: list[str]) -> None:
    for axis in ("x", "z", "y"):
        compare_value(f"{path}.{axis}", actual.get(axis), expected.get(axis), errors)


def distance_on_axes(first: dict[str, Any], second: dict[str, Any], axes: list[str]) -> float:
    return math.sqrt(sum((float(first[axis]) - float(second[axis])) ** 2 for axis in axes))


def validate(layout: dict[str, Any], contract: dict[str, Any]) -> tuple[list[str], dict[str, int]]:
    errors: list[str] = []
    stats = {
        "sections": 0,
        "ports": 0,
        "physically_adjacent_pairs_checked": 0,
        "long_route_pairs_skipped": 0,
    }

    sections = layout.get("sections")
    ports = layout.get("ports")
    if not isinstance(sections, dict):
        errors.append("layout.sections must be an object")
        sections = {}
    if not isinstance(ports, dict):
        errors.append("layout.ports must be an object")
        ports = {}

    expected_section_ids = contract["section_ids"]
    expected_ports = contract["ports"]
    expected_port_ids = list(expected_ports)
    expected_colors = contract["route_color_language"]
    expected_bounds = contract["section_bounds"]
    expected_placement = contract["section_placement"]

    compare_value("unit", layout.get("unit"), "meter", errors)
    compare_value("route_color_language", layout.get("route_color_language"), expected_colors, errors)

    same_keys(sections, expected_section_ids, "primary section", errors)
    same_keys(ports, expected_port_ids, "port", errors)
    stats["sections"] = len(sections)
    stats["ports"] = len(ports)

    for section_id in expected_section_ids:
        section = sections.get(section_id)
        if not isinstance(section, dict):
            continue
        bounds_contract = expected_bounds[section_id]
        placement_contract = expected_placement[section_id]

        compare_value(f"sections.{section_id}.bounds", section.get("bounds"), bounds_contract["bounds"], errors)
        compare_value(f"sections.{section_id}.floor_y", section.get("floor_y"), bounds_contract["floor_y"], errors)
        compare_value(
            f"sections.{section_id}.direct_neighbors",
            section.get("direct_neighbors"),
            placement_contract["direct_neighbors"],
            errors,
        )
        compare_value(
            f"sections.{section_id}.required_landmarks",
            section.get("required_landmarks"),
            placement_contract["required_landmarks"],
            errors,
        )

    section5 = sections.get("S5_UPPER_WALKWAY_OVERLAY", {})
    if section5.get("floor_y") != 6:
        errors.append("Section 5 must exist at elevated floor_y 6")
    if section5.get("is_overlay_traversal") is not True:
        errors.append("Section 5 must be marked is_overlay_traversal=true")
    if section5.get("is_normal_ground_section") is not False:
        errors.append("Section 5 must be marked is_normal_ground_section=false")

    section7 = sections.get("S7_RETURN_UTILITY_STRIP", {})
    if section7.get("floor_y") != -1:
        errors.append("Section 7 must exist at bottom floor_y -1")
    if section7.get("is_bottom_return_utility_strip") is not True:
        errors.append("Section 7 must be marked is_bottom_return_utility_strip=true")

    connected_neighbors: dict[str, set[str]] = {section_id: set() for section_id in expected_section_ids}
    checked_pairs: set[tuple[str, str]] = set()
    for port_id, expected_port in expected_ports.items():
        port = ports.get(port_id)
        if not isinstance(port, dict):
            continue

        for key in ("section", "width", "layer", "route_color", "connects_to"):
            compare_value(f"ports.{port_id}.{key}", port.get(key), expected_port[key], errors)
        compare_position(f"ports.{port_id}.position", port.get("position", {}), expected_port["position"], errors)

        section_id = port.get("section")
        target_id = port.get("connects_to")
        target = ports.get(target_id)
        if target_id not in ports:
            errors.append(f"ports.{port_id}.connects_to target missing: {target_id}")
            continue
        if isinstance(target, dict) and target.get("connects_to") != port_id:
            errors.append(f"ports.{port_id} is not reciprocal with {target_id}")

        if section_id in connected_neighbors and isinstance(target, dict):
            target_section = target.get("section")
            if target_section in connected_neighbors and target_section != section_id:
                connected_neighbors[section_id].add(target_section)

        if port.get("route_color") not in expected_colors:
            errors.append(f"ports.{port_id}.route_color is outside locked color language: {port.get('route_color')}")

        if section_id == "S7_RETURN_UTILITY_STRIP" and port.get("layer") not in APPROVED_S7_PORT_LAYERS:
            errors.append(f"Section 7 port {port_id} uses unapproved layer {port.get('layer')!r}")

        pair = tuple(sorted((port_id, str(target_id))))
        if pair in checked_pairs or target_id not in expected_ports:
            continue
        checked_pairs.add(pair)

        expected_target_position = expected_ports[target_id]["position"]
        alignment_axes = [
            axis
            for axis in ("x", "z", "y")
            if abs(float(expected_port["position"][axis]) - float(expected_target_position[axis])) <= ADJACENCY_TOLERANCE_METERS
        ]
        if len(alignment_axes) >= 2:
            stats["physically_adjacent_pairs_checked"] += 1
            actual_position = port.get("position", {})
            actual_target_position = ports[target_id].get("position", {}) if isinstance(ports.get(target_id), dict) else {}
            for axis in alignment_axes:
                delta = abs(float(actual_position.get(axis, 999999)) - float(actual_target_position.get(axis, -999999)))
                if delta > ADJACENCY_TOLERANCE_METERS:
                    errors.append(
                        f"ports.{port_id}<->{target_id} are not aligned on {axis}: "
                        f"delta {delta:.3f}m exceeds {ADJACENCY_TOLERANCE_METERS}m"
                    )
            if distance_on_axes(actual_position, actual_target_position, alignment_axes) > 100000:
                errors.append(f"ports.{port_id}<->{target_id} has invalid alignment coordinates")
        else:
            stats["long_route_pairs_skipped"] += 1

    for section_id, neighbors in connected_neighbors.items():
        approved = set(expected_placement[section_id]["direct_neighbors"])
        extra = neighbors - approved
        if extra:
            errors.append(f"sections.{section_id} has unapproved neighboring exit(s): {sorted(extra)}")

    return errors, stats


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--layout",
        default="levels/hesperus_market/layout/hesperus_market_locked_layout.json",
        help="Path to the machine-readable Hesperus Market layout JSON.",
    )
    parser.add_argument(
        "--contract",
        default="docs/level_design/hesperus_market/00_LOCKED_LAYOUT.md",
        help="Path to the locked layout source document.",
    )
    args = parser.parse_args()

    layout_path = Path(args.layout)
    contract_path = Path(args.contract)

    try:
        layout = load_json(layout_path)
        contract = contract_from_doc(contract_path)
        errors, stats = validate(layout, contract)
    except Exception as exc:
        print(f"VALIDATION ERROR: {exc}", file=sys.stderr)
        return 2

    if errors:
        print("Hesperus Market locked layout validation FAILED")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Hesperus Market locked layout validation PASSED")
    print(f"sections={stats['sections']}")
    print(f"ports={stats['ports']}")
    print(f"physically_adjacent_pairs_checked={stats['physically_adjacent_pairs_checked']}")
    print(f"long_route_pairs_skipped={stats['long_route_pairs_skipped']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
