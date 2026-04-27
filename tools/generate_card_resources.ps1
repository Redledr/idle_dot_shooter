$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Escape-GodotString {
	param([string]$Value)

	if ($null -eq $Value) {
		return ""
	}

	return $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", "").Replace("`n", "\n")
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$cardsJsonPath = Join-Path $projectRoot "data\runtime\cards.json"
$outputDir = Join-Path $projectRoot "data\cards"

$cards = (Get-Content -Raw $cardsJsonPath | ConvertFrom-Json).cards

foreach ($card in $cards) {
	$id = [string]$card.id
	if ([string]::IsNullOrWhiteSpace($id)) {
		continue
	}

	$effectType = Escape-GodotString ([string]$card.effect_key)
	$name = Escape-GodotString ([string]$card.name)
	$description = Escape-GodotString ([string]$card.description)
	$rarity = Escape-GodotString ([string]$card.rarity)
	$category = Escape-GodotString ([string]$card.category)
	$value = [double]$card.effect_value
	$idEscaped = Escape-GodotString $id

	$content = @"
[gd_resource type="Resource" script_class="CardResource" load_steps=4 format=3]

[ext_resource type="Script" path="res://data/cards/CardResource.gd" id="1_cardresource"]
[ext_resource type="Script" path="res://data/cards/CardEffectResource.gd" id="2_effectresource"]

[sub_resource type="Resource" id="Resource_effect"]
script = ExtResource("2_effectresource")
effect_type = "$effectType"
value = $value
metadata = {
"legacy_category": "$category",
"legacy_rarity": "$rarity"
}

[resource]
script = ExtResource("1_cardresource")
id = "$idEscaped"
display_name = "$name"
description = "$description"
rarity = "$rarity"
category = "$category"
effects = [SubResource("Resource_effect")]
tags = PackedStringArray()
"@

	$outputPath = Join-Path $outputDir "$id.tres"
	[System.IO.File]::WriteAllText($outputPath, $content, $utf8NoBom)
}

Write-Host ("Generated {0} card resources in {1}" -f $cards.Count, $outputDir)
