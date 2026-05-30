param(
    [string]$WalterDataRoot,
    [string]$OutputPath,
    [string]$AuditPath
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($WalterDataRoot)) {
    $WalterDataRoot = "C:\Users\rodri\Downloads\walter-0.9.1.62-20250214T060559Z-001\walter-0.9.1.62\data"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $ProjectRoot "data\rules\equipment_core.json"
}
if ([string]::IsNullOrWhiteSpace($AuditPath)) {
    $AuditPath = Join-Path $ProjectRoot "data\rules\equipment_audit.json"
}

$CoreRulesPath = Join-Path $ProjectRoot "data\rules\alternity_core.json"
$ExistingCatalogPath = $OutputPath

function Read-XmlSafe {
    param([string]$FilePath)
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlReaderSettings = New-Object System.Xml.XmlReaderSettings
    $xmlReaderSettings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $xmlReader = [System.Xml.XmlReader]::Create($FilePath, $xmlReaderSettings)
    try {
        $xmlDoc.Load($xmlReader)
    } finally {
        $xmlReader.Dispose()
    }
    return $xmlDoc
}

function Normalize-Key {
    param([string]$Value)
    return (($Value.ToLowerInvariant() -replace "[^a-z0-9]+", " ").Trim() -replace "\s+", " ")
}

function Get-XmlAttribute {
    param(
        [System.Xml.XmlElement]$Node,
        [string]$Name,
        [string]$Default = ""
    )
    if ($Node.HasAttribute($Name)) {
        return $Node.GetAttribute($Name)
    }
    return $Default
}

function Get-XmlChildText {
    param(
        [System.Xml.XmlElement]$Node,
        [string]$Name,
        [string]$Default = ""
    )
    $child = $Node.SelectSingleNode($Name)
    if ($null -ne $child) {
        return $child.InnerText
    }
    return $Default
}

function Convert-ManualNumber {
    param([string]$Value)
    $text = $Value.Trim()
    if ($text -eq "" -or $text -eq "-" -or $text -eq "varies") {
        return 0
    }
    if ($text -eq "<1") {
        return 0.5
    }
    if ($text -match "^[0-9]+(\.[0-9]+)?") {
        if ($text.Contains(".")) {
            return [double]($Matches[0])
        }
        return [int]($Matches[0])
    }
    return 0
}

function Convert-Availability {
    param([string]$Value)
    $text = $Value.Trim()
    switch ($text) {
        "0" { return "Any" }
        "1" { return "Com" }
        "2" { return "Con" }
        "3" { return "Mil" }
        "4" { return "Res" }
        default {
            if ([string]::IsNullOrWhiteSpace($text)) {
                return "Com"
            }
            return $text
        }
    }
}

function New-Reference {
    param(
        [string]$Page,
        [string]$Table,
        [string]$Title
    )
    return [ordered]@{
        book = "Player's Handbook"
        page = $Page
        table = $Table
        title = $Title
    }
}

function Format-Reference {
    param([hashtable]$Reference)
    return "Player's Handbook p. {0}, Table {1}: {2}" -f $Reference.page, $Reference.table, $Reference.title
}

$existingByKey = @{}
$usedIds = @{}
if (Test-Path -LiteralPath $ExistingCatalogPath) {
    $existing = Get-Content -LiteralPath $ExistingCatalogPath -Raw | ConvertFrom-Json
    foreach ($item in $existing.items) {
        $key = "{0}|{1}" -f $item.kind, (Normalize-Key $item.name)
        if (-not $existingByKey.ContainsKey($key)) {
            $existingByKey[$key] = $item.id
        }
        $usedIds[$item.id] = $true
    }
}

$nextId = @{
    equipment = 1
    weapon = 1
    armor = 1
}

function New-CatalogId {
    param([string]$Kind)
    $prefix = switch ($Kind) {
        "equipment" { "equip_phb" }
        "weapon" { "weapon_phb" }
        "armor" { "armor_phb" }
        default { "item_phb" }
    }
    do {
        $id = "{0}_{1:D3}" -f $prefix, $script:nextId[$Kind]
        $script:nextId[$Kind] += 1
    } while ($script:usedIds.ContainsKey($id))
    $script:usedIds[$id] = $true
    return $id
}

function Get-CatalogId {
    param(
        [string]$Kind,
        [string]$Name,
        [string[]]$Aliases = @()
    )
    foreach ($candidate in @($Name) + $Aliases) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        $key = "{0}|{1}" -f $Kind, (Normalize-Key $candidate)
        if ($script:existingByKey.ContainsKey($key)) {
            return $script:existingByKey[$key]
        }
    }
    return New-CatalogId $Kind
}

$coreRules = Get-Content -LiteralPath $CoreRulesPath -Raw | ConvertFrom-Json
$skillsById = @{}
foreach ($skill in $coreRules.skills) {
    $skillsById[[int]$skill.id] = $skill
}

function Get-SkillLabel {
    param([int]$SkillId)
    if ($SkillId -lt 0 -or -not $script:skillsById.ContainsKey($SkillId)) {
        return "None"
    }
    $skill = $script:skillsById[$SkillId]
    $broadId = [int]$skill.broad_id
    if ($broadId -eq $SkillId -or -not $script:skillsById.ContainsKey($broadId)) {
        return [string]$skill.name
    }
    $broad = $script:skillsById[$broadId]
    return "{0} - {1}" -f $broad.name, $skill.name
}

function Get-WeaponClass {
    param([int]$SkillId)
    switch ($SkillId) {
        6 { return "Thrown Weapons" }
        9 { return "Heavy Weapons" }
        10 { return "Heavy Weapons" }
        12 { return "Melee Weapons" }
        13 { return "Melee Weapons" }
        14 { return "Melee Weapons" }
        15 { return "Melee Weapons" }
        16 { return "Melee Weapons" }
        31 { return "Modern Ranged Weapons" }
        32 { return "Modern Ranged Weapons" }
        33 { return "Modern Ranged Weapons" }
        35 { return "Primitive Ranged Weapons" }
        37 { return "Primitive Ranged Weapons" }
        38 { return "Primitive Ranged Weapons" }
        default { return "Weapons" }
    }
}

function Get-ArmorClass {
    param([int]$SkillId)
    switch ($SkillId) {
        -1 { return "None" }
        0 { return "Armor Operation" }
        1 { return "Armor Operation - Combat armor" }
        2 { return "Armor Operation - Powered armor" }
        default { return Get-SkillLabel $SkillId }
    }
}

$manualEquipmentJson = @'
[
  {"name":"Antiscan weave","category":"Accessories and Clothing","class":"Clothing","pl":7,"mass":"-","cost":"Cost x 3"},
  {"name":"Backpack","category":"Accessories and Clothing","class":"Accessories","pl":4,"mass":"1","cost":"100"},
  {"name":"Bioholster","category":"Accessories and Clothing","class":"Accessories","pl":6,"mass":"1","cost":"150"},
  {"name":"Boots","category":"Accessories and Clothing","class":"Clothing","pl":2,"mass":"1","cost":"100"},
  {"name":"Briefcase","category":"Accessories and Clothing","class":"Accessories","pl":3,"mass":"1","cost":"60"},
  {"name":"Business dress","category":"Accessories and Clothing","class":"Clothing","pl":3,"mass":"-","cost":"300"},
  {"name":"Casual dress","category":"Accessories and Clothing","class":"Clothing","pl":3,"mass":"-","cost":"50"},
  {"name":"Coat","category":"Accessories and Clothing","class":"Clothing","pl":1,"mass":"1","cost":"100"},
  {"name":"Fatigues","category":"Accessories and Clothing","class":"Clothing","pl":5,"mass":"-","cost":"50"},
  {"name":"Formal dress","category":"Accessories and Clothing","class":"Clothing","pl":3,"mass":"-","cost":"500"},
  {"name":"Glasses","category":"Accessories and Clothing","class":"Accessories","pl":3,"mass":"-","cost":"50"},
  {"name":"Goggles, protective","category":"Accessories and Clothing","class":"Accessories","pl":4,"mass":"-","cost":"25"},
  {"name":"Holster/scabbard","aliases":["Holster"],"category":"Accessories and Clothing","class":"Accessories","pl":1,"mass":"1","cost":"25"},
  {"name":"Jewelry","category":"Accessories and Clothing","class":"Accessories","pl":1,"mass":"-","cost":"100"},
  {"name":"Pouch","category":"Accessories and Clothing","class":"Accessories","pl":2,"mass":"-","cost":"50"},
  {"name":"Shoes, athletic","category":"Accessories and Clothing","class":"Clothing","pl":5,"mass":"-","cost":"150"},
  {"name":"Shoes, business","category":"Accessories and Clothing","class":"Clothing","pl":4,"mass":"-","cost":"50"},
  {"name":"Shoes, formal","category":"Accessories and Clothing","class":"Clothing","pl":4,"mass":"-","cost":"100"},
  {"name":"Stealth cloak","category":"Accessories and Clothing","class":"Clothing","pl":8,"mass":"1","cost":"750"},
  {"name":"Utility harness","category":"Accessories and Clothing","class":"Accessories","pl":4,"mass":"-","cost":"25"},
  {"name":"Watch","category":"Accessories and Clothing","class":"Accessories","pl":4,"mass":"-","cost":"50"},
  {"name":"Cellular phone","category":"Communications","class":"Communications","pl":5,"mass":"-","cost":"100"},
  {"name":"Comm gear","category":"Communications","class":"Communications","pl":7,"mass":"-","cost":"175"},
  {"name":"Command link","category":"Communications","class":"Communications","pl":5,"mass":"1","cost":"250"},
  {"name":"Mass transceiver","category":"Communications","class":"Communications","pl":7,"mass":"500","cost":"40000"},
  {"name":"Orbital uplink","category":"Communications","class":"Communications","pl":5,"mass":"2","cost":"200"},
  {"name":"Radio, personal","category":"Communications","class":"Communications","pl":5,"mass":"1","cost":"175"},
  {"name":"First aid kit","category":"Medical Gear","class":"Medical Gear","pl":4,"mass":"2","cost":"50"},
  {"name":"Forensics kit","category":"Medical Gear","class":"Medical Gear","pl":5,"mass":"5","cost":"250"},
  {"name":"Life support pack","category":"Medical Gear","class":"Medical Gear","pl":7,"mass":"3","cost":"500"},
  {"name":"Medical gauntlet","category":"Medical Gear","class":"Medical Gear","pl":7,"mass":"2","cost":"1250"},
  {"name":"Medical scanner","category":"Medical Gear","class":"Medical Gear","pl":6,"mass":"10","cost":"3000"},
  {"name":"Pharmaceuticals - Anesthetic (dose)","category":"Medical Gear","class":"Medical Gear","pl":4,"mass":"-","cost":"50"},
  {"name":"Pharmaceuticals - Antibiotic (dose)","aliases":["Pharmaceuticals Antibiotic (dose)"],"category":"Medical Gear","class":"Medical Gear","pl":5,"mass":"-","cost":"50"},
  {"name":"Pharmaceuticals - Antiradiation (dose)","category":"Medical Gear","class":"Medical Gear","pl":6,"mass":"-","cost":"100"},
  {"name":"Pharmaceuticals - Antivenom (dose)","aliases":["Pharmaceuticals Antivenom (dose)"],"category":"Medical Gear","class":"Medical Gear","pl":5,"mass":"-","cost":"75"},
  {"name":"Pharmaceuticals - Coagulant (dose)","category":"Medical Gear","class":"Medical Gear","pl":6,"mass":"-","cost":"50"},
  {"name":"Pharmaceuticals - Psi-enhancer (dose)","aliases":["Pharmaceuticals Psi-enhancer (dose)"],"category":"Medical Gear","class":"Medical Gear","pl":7,"mass":"-","cost":"150"},
  {"name":"Pharmaceuticals - Sedative (dose)","category":"Medical Gear","class":"Medical Gear","pl":5,"mass":"-","cost":"25"},
  {"name":"Pharmaceuticals - Stimulant (dose)","aliases":["Pharmaceuticals Stimulant (dose)"],"category":"Medical Gear","class":"Medical Gear","pl":5,"mass":"-","cost":"25"},
  {"name":"Surgical kit","category":"Medical Gear","class":"Medical Gear","pl":6,"mass":"15","cost":"1250"},
  {"name":"Trauma pack I","category":"Medical Gear","class":"Medical Gear","pl":6,"mass":"1","cost":"200"},
  {"name":"Trauma pack II","category":"Medical Gear","class":"Medical Gear","pl":7,"mass":"2","cost":"400"},
  {"name":"Chain hoist","category":"Professional Equipment","class":"Professional Equipment","pl":4,"mass":"20","cost":"150"},
  {"name":"Cutting torch","category":"Professional Equipment","class":"Professional Equipment","pl":5,"mass":"10","cost":"250"},
  {"name":"Demolitions pack","category":"Professional Equipment","class":"Professional Equipment","pl":5,"mass":"25","cost":"750"},
  {"name":"Generator, portable","category":"Professional Equipment","class":"Professional Equipment","pl":5,"mass":"25","cost":"500"},
  {"name":"Instrument pack","category":"Professional Equipment","class":"Professional Equipment","pl":6,"mass":"15","cost":"500"},
  {"name":"Rescue pack","category":"Professional Equipment","class":"Professional Equipment","pl":5,"mass":"20","cost":"500"},
  {"name":"Toolkit","category":"Professional Equipment","class":"Professional Equipment","pl":4,"mass":"10","cost":"100"},
  {"name":"Toolkit, special","category":"Professional Equipment","class":"Professional Equipment","pl":5,"mass":"10","cost":"300"},
  {"name":"Walker","category":"Professional Equipment","class":"Professional Equipment","pl":6,"mass":"200","cost":"2000"},
  {"name":"Weight neutralizer","category":"Professional Equipment","class":"Professional Equipment","pl":7,"mass":"4","cost":"300"},
  {"name":"Workshop, portable","category":"Professional Equipment","class":"Professional Equipment","pl":6,"mass":"100","cost":"1000"},
  {"name":"Audiorecorder","category":"Sensors","class":"Sensors","pl":5,"mass":"1","cost":"50"},
  {"name":"Binoculars","category":"Sensors","class":"Sensors","pl":4,"mass":"1","cost":"225"},
  {"name":"Compass","category":"Sensors","class":"Sensors","pl":3,"mass":"-","cost":"25"},
  {"name":"Goggles, imaging","category":"Sensors","class":"Sensors","pl":5,"mass":"2","cost":"300"},
  {"name":"Goggles, infrared","category":"Sensors","class":"Sensors","pl":5,"mass":"2","cost":"250"},
  {"name":"GPS receiver","category":"Sensors","class":"Sensors","pl":5,"mass":"-","cost":"150"},
  {"name":"Holorecorder","category":"Sensors","class":"Sensors","pl":7,"mass":"1","cost":"1200"},
  {"name":"Microphone, para.","category":"Sensors","class":"Sensors","pl":5,"mass":"3","cost":"375"},
  {"name":"Psi-detector","category":"Sensors","class":"Sensors","pl":6,"mass":"4","cost":"2500"},
  {"name":"Radar gauntlet","category":"Sensors","class":"Sensors","pl":7,"mass":"2","cost":"350"},
  {"name":"Sensor boom","category":"Sensors","class":"Sensors","pl":5,"mass":"1","cost":"75"},
  {"name":"Sensor gauntlet","category":"Sensors","class":"Sensors","pl":7,"mass":"2","cost":"725"},
  {"name":"Surveillance gear","category":"Sensors","class":"Sensors","pl":5,"mass":"-","cost":"250"},
  {"name":"Videorecorder","aliases":["Video recorder"],"category":"Sensors","class":"Sensors","pl":5,"mass":"1","cost":"500"},
  {"name":"Weapon detector","category":"Sensors","class":"Sensors","pl":6,"mass":"1","cost":"125"},
  {"name":"Animal, guard","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":1,"mass":"varies","cost":"varies"},
  {"name":"Animal, mount","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":1,"mass":"varies","cost":"varies"},
  {"name":"Animal, pack","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":1,"mass":"varies","cost":"varies"},
  {"name":"Animal, pet","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":1,"mass":"varies","cost":"varies"},
  {"name":"Biolock","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":6,"mass":"-","cost":"100"},
  {"name":"Duct tape","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":5,"mass":"-","cost":"10/roll"},
  {"name":"Ear plugs","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":4,"mass":"-","cost":"10"},
  {"name":"Fire extinguisher","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":5,"mass":"5","cost":"25"},
  {"name":"Handcuffs","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":4,"mass":"1","cost":"50"},
  {"name":"Holoviewer","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":7,"mass":"3","cost":"500"},
  {"name":"Instant glue","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":5,"mass":"-","cost":"5"},
  {"name":"Lockpick set","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":4,"mass":"1","cost":"75"},
  {"name":"Magnetic clamp","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":6,"mass":"1","cost":"50"},
  {"name":"Music gauntlet","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":7,"mass":"2","cost":"250"},
  {"name":"Musical instrument","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":3,"mass":"varies","cost":"varies"},
  {"name":"Padlock","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":4,"mass":"-","cost":"10"},
  {"name":"Psi-restraint helm","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":6,"mass":"2","cost":"1200"},
  {"name":"Psi-restraint collar","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":6,"mass":"1","cost":"1700"},
  {"name":"Psi-restraint implant","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":6,"mass":"-","cost":"3500"},
  {"name":"Suitcase","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":4,"mass":"2","cost":"50"},
  {"name":"Videoviewer","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":5,"mass":"7","cost":"200"},
  {"name":"Weapon biokey","category":"Miscellaneous Gear","class":"Miscellaneous Gear","pl":6,"mass":"-","cost":"75"},
  {"name":"Bedroll","category":"Survival Gear","class":"Survival Gear","pl":2,"mass":"4","cost":"25"},
  {"name":"Boots, magnetic","category":"Survival Gear","class":"Survival Gear","pl":6,"mass":"4","cost":"350"},
  {"name":"Cabin, portable","category":"Survival Gear","class":"Survival Gear","pl":7,"mass":"40","cost":"650"},
  {"name":"Camping unit","category":"Survival Gear","class":"Survival Gear","pl":6,"mass":"10","cost":"300"},
  {"name":"Candle","category":"Survival Gear","class":"Survival Gear","pl":1,"mass":"-","cost":"1"},
  {"name":"Climate weave","category":"Survival Gear","class":"Survival Gear","pl":7,"mass":"-","cost":"Cost x 2"},
  {"name":"Climbing gear","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"10","cost":"100"},
  {"name":"Cooler","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"5","cost":"50"},
  {"name":"Emergency beacon","category":"Survival Gear","class":"Survival Gear","pl":5,"mass":"10","cost":"200"},
  {"name":"E-suit, soft","category":"Survival Gear","class":"Survival Gear","pl":5,"mass":"10","cost":"2500"},
  {"name":"E-suit, hard","category":"Survival Gear","class":"Survival Gear","pl":6,"mass":"20","cost":"4000"},
  {"name":"Flare","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"1","cost":"5"},
  {"name":"Flashlight","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"1","cost":"25"},
  {"name":"Grappling hook","category":"Survival Gear","class":"Survival Gear","pl":2,"mass":"1","cost":"20"},
  {"name":"Habitat dome","category":"Survival Gear","class":"Survival Gear","pl":6,"mass":"50","cost":"1500"},
  {"name":"Heater, portable","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"8","cost":"75"},
  {"name":"Jumpsuit","category":"Survival Gear","class":"Survival Gear","pl":6,"mass":"3","cost":"750"},
  {"name":"Lantern","category":"Survival Gear","class":"Survival Gear","pl":3,"mass":"1","cost":"50"},
  {"name":"Lighter","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"-","cost":"5"},
  {"name":"Machete","category":"Survival Gear","class":"Survival Gear","pl":3,"mass":"2","cost":"25"},
  {"name":"Matches","category":"Survival Gear","class":"Survival Gear","pl":3,"mass":"-","cost":"5/box"},
  {"name":"Mirror","category":"Survival Gear","class":"Survival Gear","pl":1,"mass":"-","cost":"10"},
  {"name":"Parachute","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"5","cost":"100"},
  {"name":"Raft, inflatable","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"5","cost":"100"},
  {"name":"Rations (1 wk.)","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"2","cost":"25"},
  {"name":"Respirator mask","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"1","cost":"125"},
  {"name":"Rope, 50 m","aliases":["Rope, 50m"],"category":"Survival Gear","class":"Survival Gear","pl":1,"mass":"5","cost":"25"},
  {"name":"Scuba gear","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"15","cost":"500"},
  {"name":"Skis","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"3","cost":"150"},
  {"name":"Stove, portable","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"4","cost":"100"},
  {"name":"Survival gear","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"3","cost":"70"},
  {"name":"Tent","category":"Survival Gear","class":"Survival Gear","pl":3,"mass":"10","cost":"100"},
  {"name":"Torch","category":"Survival Gear","class":"Survival Gear","pl":1,"mass":"1","cost":"10"},
  {"name":"Vacuum mask","category":"Survival Gear","class":"Survival Gear","pl":6,"mass":"2","cost":"200"},
  {"name":"Water condenser","category":"Survival Gear","class":"Survival Gear","pl":5,"mass":"5","cost":"250"},
  {"name":"Water purifier","category":"Survival Gear","class":"Survival Gear","pl":4,"mass":"7","cost":"175"},
  {"name":"Weather monitor","category":"Survival Gear","class":"Survival Gear","pl":6,"mass":"1","cost":"75"},
  {"name":"Zero-g web","category":"Survival Gear","class":"Survival Gear","pl":6,"mass":"3","cost":"350"}
]
'@ | ConvertFrom-Json

$items = New-Object System.Collections.Generic.List[object]
$auditItems = New-Object System.Collections.Generic.List[object]
$phbEquipmentReference = New-Reference "135-136" "P33" "Personal Equipment"

foreach ($row in $manualEquipmentJson) {
    $aliases = @()
    if ($row.PSObject.Properties.Name -contains "aliases") {
        $aliases = @($row.aliases)
    }
    $massText = [string]$row.mass
    $costText = [string]$row.cost
    $item = [ordered]@{
        id = Get-CatalogId "equipment" ([string]$row.name) $aliases
        kind = "equipment"
        name = [string]$row.name
        source = "Player's Handbook"
        source_code = "phb"
        reference = Format-Reference $phbEquipmentReference
        references = @($phbEquipmentReference)
        page = "135-136"
        table = "P33"
        pl = [int]$row.pl
        category = [string]$row.category
        class = [string]$row.class
        availability = "Com"
        mass = Convert-ManualNumber $massText
        cost = Convert-ManualNumber $costText
        combat = $null
    }
    if ($massText -notmatch "^[0-9]+(\.[0-9]+)?$") {
        $item.mass_text = $massText
    }
    if ($costText -notmatch "^[0-9]+$") {
        $item.cost_text = $costText
    }
    $items.Add($item)
    $auditItems.Add([ordered]@{
        id = $item.id
        kind = "equipment"
        name = $item.name
        status = "manual_table_p33"
        reference = $item.reference
    })
}

$weaponNameCorrections = @{
    "Greate ax" = "Great ax"
    "Plasma Gun" = "Plasma gun"
    "Pistol, heavy maser" = "Pistol, hvy maser"
    "Rifle, heavy maser" = "Rifle, hvy maser"
}

$weaponValueCorrections = @{
    "Bow, short" = @{ range = "20/40/100" }
    "Rifle, assault" = @{ clip_size = "30/10" }
    "SMG, .45 cal" = @{ clip_size = "--/8" }
    "SMG, 9mm" = @{ clip_size = "--/10" }
    "Rifle, 11mm ch" = @{ clip_size = "30/10" }
    "Shotgun, autoflec" = @{ clip_size = "15/5" }
    "SMG, 9mm ch" = @{ clip_size = "--/10" }
    "Rifle, quantum" = @{ clip_size = "15/5" }
    "SMG, laser" = @{ clip_size = "--/10" }
    "SMG, stutter" = @{ clip_size = "--/20" }
    "Automaser" = @{ clip_size = "--/20" }
    "Rifle, hvy maser" = @{ clip_size = "60/20" }
    "Rifle, maser" = @{ clip_size = "90/30" }
    "Machine gun, .30" = @{ clip_size = "--/50" }
    "Heavy machine gun" = @{ clip_size = "--/50" }
    "Heavy machine gun, ch" = @{ clip_size = "--/50" }
    "Rail gun" = @{ clip_size = "--/30" }
    "Quantum mini" = @{ clip_size = "90/30" }
}

function Get-WeaponReference {
    param([string]$Class)
    switch ($Class) {
        "Melee Weapons" { return New-Reference "172-173" "P38" "Melee Weapons" }
        "Heavy Weapons" { return New-Reference "182-183" "P40" "Heavy Weapons" }
        default { return New-Reference "176-177" "P39" "Ranged Weapons" }
    }
}

$weaponXmlPath = Join-Path $WalterDataRoot "weapon_Core.xml"
$weaponXml = Read-XmlSafe -FilePath $weaponXmlPath
foreach ($node in $weaponXml.SelectNodes("//AttackForm")) {
    $originalName = Get-XmlAttribute $node "Name"
    $name = if ($weaponNameCorrections.ContainsKey($originalName)) { $weaponNameCorrections[$originalName] } else { $originalName }
    $skillId = [int](Get-XmlAttribute $node "SkillID" "-1")
    $weaponType = Get-XmlAttribute $node "Type"
    $class = if ($weaponType -eq "2") { "Heavy Weapons" } elseif ($weaponType -eq "0") { "Melee Weapons" } else { Get-WeaponClass $skillId }
    $reference = Get-WeaponReference $class
    $clipSize = Get-XmlAttribute $node "ClipSize" "0"
    if ($weaponValueCorrections.ContainsKey($name) -and $weaponValueCorrections[$name].ContainsKey("clip_size")) {
        $clipSize = $weaponValueCorrections[$name].clip_size
    }
    elseif ($weaponValueCorrections.ContainsKey($originalName) -and $weaponValueCorrections[$originalName].ContainsKey("clip_size")) {
        $clipSize = $weaponValueCorrections[$originalName].clip_size
    }
    $range = Get-XmlAttribute $node "Range"
    if ($weaponValueCorrections.ContainsKey($name) -and $weaponValueCorrections[$name].ContainsKey("range")) {
        $range = $weaponValueCorrections[$name].range
    }

    $item = [ordered]@{
        id = Get-CatalogId "weapon" $name @($originalName)
        kind = "weapon"
        name = $name
        source = "Player's Handbook"
        source_code = "phb"
        reference = Format-Reference $reference
        references = @($reference)
        page = $reference.page
        table = $reference.table
        pl = [int](Get-XmlAttribute $node "PL" "0")
        category = "Weapons"
        class = $class
        availability = Convert-Availability (Get-XmlAttribute $node "Availability" "Com")
        mass = Convert-ManualNumber (Get-XmlAttribute $node "Mass" "0")
        cost = [int](Convert-ManualNumber (Get-XmlAttribute $node "Cost" "0"))
        combat = [ordered]@{
            skill_id = $skillId
            skill = Get-SkillLabel $skillId
            accuracy = [int](Get-XmlAttribute $node "Accuracy" "0")
            mode = Get-XmlAttribute $node "Mode"
            range = $range
            damage = Get-XmlChildText $node "Damage"
            damage_type = Get-XmlAttribute $node "DamageType"
            actions = [int](Get-XmlAttribute $node "Actions" "0")
            clip_size = $clipSize
            clip_cost = [int](Convert-ManualNumber (Get-XmlAttribute $node "ClipCost" "0"))
            hide = [int](Get-XmlAttribute $node "Hide" "-1000")
            strength_based = [System.Convert]::ToBoolean((Get-XmlAttribute $node "STRBased" "False"))
            melee = [System.Convert]::ToBoolean((Get-XmlAttribute $node "Melee" "False"))
            thrown = [System.Convert]::ToBoolean((Get-XmlAttribute $node "Throw" "False"))
            type = Get-XmlAttribute $node "DamageType"
        }
    }
    $items.Add($item)
    $auditItems.Add([ordered]@{
        id = $item.id
        kind = "weapon"
        name = $item.name
        status = "manual_table_$($reference.table.ToLowerInvariant())"
        reference = $item.reference
        structured_baseline = "WAlter core XML, checked against Player's Handbook table images/OCR"
    })
}

$armorNameCorrections = @{
    "Body tank, overland" = "Body tank, overland"
}

$armorXmlPath = Join-Path $WalterDataRoot "armor_Core.xml"
$armorXml = Read-XmlSafe -FilePath $armorXmlPath
$armorReference = New-Reference "188" "P41" "Armor"
foreach ($node in $armorXml.SelectNodes("//ArmorItem")) {
    $originalName = Get-XmlAttribute $node "Name"
    $name = if ($armorNameCorrections.ContainsKey($originalName)) { $armorNameCorrections[$originalName] } else { $originalName }
    $skillId = [int](Get-XmlAttribute $node "SkillID" "-1")
    $item = [ordered]@{
        id = Get-CatalogId "armor" $name @($originalName)
        kind = "armor"
        name = $name
        source = "Player's Handbook"
        source_code = "phb"
        reference = Format-Reference $armorReference
        references = @($armorReference)
        page = $armorReference.page
        table = $armorReference.table
        pl = [int](Get-XmlAttribute $node "PL" "0")
        category = "Armor"
        class = Get-ArmorClass $skillId
        availability = Convert-Availability (Get-XmlAttribute $node "Availability" "Com")
        mass = Convert-ManualNumber (Get-XmlAttribute $node "Mass" "0")
        cost = [int](Convert-ManualNumber (Get-XmlAttribute $node "Cost" "0"))
        combat = [ordered]@{
            skill_id = $skillId
            skill = Get-ArmorClass $skillId
            action_penalty = [int](Get-XmlAttribute $node "AP" "0")
            toughness = Get-XmlChildText $node "Toughness" (Get-XmlAttribute $node "Toughness")
            li = Get-XmlAttribute $node "LI"
            hi = Get-XmlAttribute $node "HI"
            en = Get-XmlAttribute $node "En"
            hide = [int](Get-XmlAttribute $node "Hide" "-1000")
        }
    }
    $items.Add($item)
    $auditItems.Add([ordered]@{
        id = $item.id
        kind = "armor"
        name = $item.name
        status = "manual_table_p41"
        reference = $item.reference
        structured_baseline = "WAlter core XML, checked against Player's Handbook table images/OCR"
    })
}

$catalog = [ordered]@{
    version = 2
    generated_by = "tools/extract_equipment_catalog.ps1"
    generated_on = (Get-Date).ToString("yyyy-MM-dd")
    scope = "Core Player's Handbook character equipment, weapons, and armor. GMG vehicle/spaceship gear is intentionally out of character-carried scope for this iteration."
    sources = @(
        [ordered]@{
            id = "phb"
            name = "Player's Handbook"
            reference = "Tables P33, P38, P39, P40, and P41"
        }
    )
    items = $items.ToArray()
}

$audit = [ordered]@{
    generated_on = (Get-Date).ToString("yyyy-MM-dd")
    manuals = @(
        [ordered]@{ name = "Alternity 01 Players Handbook.pdf"; used_for = "Core character equipment, weapons, and armor tables"; pages = "135-136, 172-173, 176-177, 182-183, 188" },
        [ordered]@{ name = "Alternity 00 Gamemaster Guide.pdf"; used_for = "Reviewed for character-usable gear scope; vehicle/spaceship gear deferred"; pages = "Chapter 10+ vehicle material is out of current carried-equipment scope" }
    )
    notes = @(
        "Personal equipment is transcribed from PHB Table P33.",
        "Weapon and armor rows preserve stable WAlter IDs where possible, while names, references, availability labels, damage type, selected range/clip display values, and catalog coverage are aligned to PHB Tables P38-P41.",
        "Unarmed appears by default in the summary attack forms and is not added as carried catalog equipment."
    )
    counts = [ordered]@{
        equipment = @($items | Where-Object { $_.kind -eq "equipment" }).Count
        weapon = @($items | Where-Object { $_.kind -eq "weapon" }).Count
        armor = @($items | Where-Object { $_.kind -eq "armor" }).Count
        total = $items.Count
    }
    items = $auditItems.ToArray()
}

$jsonOptions = @{ Depth = 20 }
$catalog | ConvertTo-Json @jsonOptions | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$audit | ConvertTo-Json @jsonOptions | Set-Content -LiteralPath $AuditPath -Encoding UTF8

Write-Host "Wrote $OutputPath"
Write-Host "Wrote $AuditPath"
Write-Host ("Counts: equipment={0}, weapon={1}, armor={2}, total={3}" -f $audit.counts.equipment, $audit.counts.weapon, $audit.counts.armor, $audit.counts.total)
