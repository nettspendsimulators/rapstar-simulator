class_name LiveRules
extends Resource
## Shows, turnês, festivais e merchandising. A instância fica em data/live.tres.

const MODEL_INDEPENDENT := "independent"
const MODEL_FIXED := "fixed"
const MODEL_PERCENTAGE := "percentage"
const MODEL_FEE_PLUS_PERCENTAGE := "fee_plus_percentage"
const MODEL_GUARANTEE := "guarantee"
const MODELS := [MODEL_INDEPENDENT, MODEL_FIXED, MODEL_PERCENTAGE, MODEL_FEE_PLUS_PERCENTAGE, MODEL_GUARANTEE]
const MODEL_LABELS := {
	MODEL_INDEPENDENT: "Independente (você organiza e assume o risco)",
	MODEL_FIXED: "Cachê fixo",
	MODEL_PERCENTAGE: "Porcentagem da bilheteria",
	MODEL_FEE_PLUS_PERCENTAGE: "Cachê + porcentagem",
	MODEL_GUARANTEE: "Garantia mínima contra porcentagem",
}
const GUEST_ROLES := ["opening", "guest", "special", "co_headliner"]
const GUEST_ROLE_LABELS := {"opening": "Abertura", "guest": "Convidado", "special": "Participação especial", "co_headliner": "Co-headliner"}
const POSITIONS := ["opening", "support", "featured", "sub_headliner", "co_headliner", "headliner"]
const POSITION_LABELS := {
	"opening": "Abertura", "support": "Suporte", "featured": "Destaque",
	"sub_headliner": "Sub-headliner", "co_headliner": "Co-headliner", "headliner": "Headliner",
}

@export var cities: Array[CityDefinition] = []
@export var venues: Array[VenueCategoryDefinition] = []
@export var production_levels: Array[ProductionLevelDefinition] = []
@export var addons: Array[ProductionAddonDefinition] = []
@export var crew_roles: Array[CrewRoleDefinition] = []
@export var merch_products: Array[MerchProductDefinition] = []
@export var festivals: Array[FestivalDefinition] = []
@export var sponsors: Array[SponsorDefinition] = []
@export var tour_types: Array[TourTypeDefinition] = []

@export_group("Carreira")
@export var home_city_id: String = "sao_paulo"
@export var weeks_per_year: int = 52
## Fama para o público de fora do país conhecer o artista por completo.
@export var international_reach_fame: int = 3000
@export var min_international_reach: float = 0.05

@export_group("Público")
@export var base_locals: int = 30
@export var fame_draw: float = 0.5
@export var follower_draw: float = 0.003
@export var price_elasticity: float = 1.2
## Fama que dobra o preço que o público aceita pagar.
@export var price_fame_reference: int = 8000
## Quanto a fama pode subir o preço que o público aceita (0,8 = até 80% acima da referência).
@export var max_price_fame_bonus: float = 0.8
@export var min_price_factor: float = 0.1
@export var max_price_factor: float = 1.5
@export var promotion_max_bonus: float = 0.3
## Investimento em divulgação, por lugar, para o bônus máximo.
@export var promotion_per_seat: float = 2.0
@export var production_hype_per_tier: float = 0.03
@export var city_saturation_weeks: int = 8
@export var city_saturation_factor: float = 0.7
@export var recent_release_weeks: int = 8
@export var recent_release_bonus: float = 0.1
@export var demand_noise: float = 0.15
@export var vip_capacity_share: float = 0.08
@export var vip_demand_share: float = 0.1
@export var vip_price_multiplier: float = 3.0

@export_group("Convidados")
## Fama equivalente de um convidado, por dólar do custo dele no catálogo.
@export var guest_fame_per_cost: float = 0.01
@export var guest_draw := {"opening": 0.15, "guest": 0.3, "special": 0.4, "co_headliner": 0.8}
@export var guest_fee := {"opening": 0.01, "guest": 0.03, "special": 0.05, "co_headliner": 0.08}
## Parte da receita que fica com o co-headliner.
@export var co_headliner_revenue_share: float = 0.4

@export_group("Custos")
@export var ticket_fee_rate: float = 0.15
@export var agent_commission: float = 0.1
@export var security_per_seat: float = 0.5
@export var food_per_person: int = 30
@export var hotel_per_person_night: int = 80
@export var local_transport: int = 100
@export var transport_per_km_person: float = 0.12
@export var flight_distance_km: int = 1500
@export var flight_per_person: int = 250
@export var production_size_reference: int = 3000
@export var min_size_factor: float = 0.2
@export var crew_tier_multipliers: Array[float] = [0.0, 1.0, 3.0, 8.0]
@export var crew_tier_labels: Array[String] = ["Sem", "Básico", "Profissional", "Elite"]
## Parte das despesas pagas antes que é devolvida se o show for cancelado.
@export var cancel_refund: float = 0.5

@export_group("Qualidade")
@export var base_quality: int = 30
@export var catalog_quality_weight: float = 0.3
@export var fatigue_quality_penalty: float = 0.3
## Organização que cada 1.000 lugares exigem; o que faltar reduz a qualidade.
@export var organization_per_thousand: float = 0.5
@export var organization_shortfall_penalty: int = 3

@export_group("Desgaste")
@export var fatigue_per_show: int = 10
@export var fatigue_per_travel_day: int = 4
@export var rest_recovery: int = 12
@export var travel_km_per_day: int = 1000
## Viagens até esta distância cabem no próprio dia do show.
@export var short_trip_km: int = 600
@export var max_travel_days: int = 2
@export var manager_fatigue_reduction: float = 0.1

@export_group("Resultados")
@export var fan_rate: float = 0.05
@export var attendees_per_fame: int = 400
## Fama a partir da qual cada show rende metade da fama: no topo, manter-se é mais difícil.
@export var show_fame_softcap: int = 4000
@export var reputation_quality: int = 70

@export_group("Merchandising")
@export var show_buy_rate: float = 0.15
@export var max_show_buy_rate: float = 0.35
@export var merch_price_elasticity: float = 1.5
@export var limited_bonus: float = 1.3
@export var exclusive_bonus: float = 1.2
@export var venue_merch_cut: float = 0.15
@export var festival_merch_cut: float = 0.25
@export var online_rate: float = 0.0005
@export var online_fee: float = 0.1
@export var volume_discounts := {500: 0.1, 2000: 0.2}

@export_group("Ofertas")
@export var base_offers_per_week: float = 0.4
@export var offers_per_fame: float = 0.0005
@export var max_offers_per_week: int = 2
@export var offer_expiry_weeks: int = 2
@export var offer_lead_min: int = 2
@export var offer_lead_max: int = 6
## Parte da bilheteria esperada que vira cachê.
@export var offer_fee_share: float = 0.35
@export var min_offer_fee: int = 100
@export var private_event_chance: float = 0.15
@export var private_event_fee_multiplier: float = 1.6

@export_group("Festivais")
## Fama para ser headliner de um festival, por ponto de prestígio.
@export var festival_fame_per_prestige: int = 50
@export var position_thresholds := {"support": 0.1, "featured": 0.25, "sub_headliner": 0.5, "co_headliner": 0.8, "headliner": 1.2}
@export var position_fee := {"opening": 0.02, "support": 0.05, "featured": 0.12, "sub_headliner": 0.3, "co_headliner": 0.6, "headliner": 1.0}
@export var position_draw := {"opening": 0.1, "support": 0.2, "featured": 0.35, "sub_headliner": 0.55, "co_headliner": 0.75, "headliner": 0.9}
@export var position_impact := {"opening": 1.0, "support": 1.2, "featured": 1.5, "sub_headliner": 2.0, "co_headliner": 2.7, "headliner": 3.5}
@export var position_minutes := {"opening": 30, "support": 40, "featured": 50, "sub_headliner": 60, "co_headliner": 75, "headliner": 90}
@export var reduced_set_factor: float = 0.6
@export var invite_base_chance: float = 0.1
@export var invite_relevance_chance: float = 0.3
@export var max_invite_chance: float = 0.6
@export var min_invite_relevance: float = 0.05
@export var invite_window_min: int = 4
@export var invite_window_max: int = 16
@export var application_chance_per_relevance: float = 1.5
@export var lineup_slots_per_stage: int = 5

@export_group("Patrocínios")
@export var sponsor_value_per_fame: float = 0.001
@export var sponsor_value_per_show: float = 0.25
@export var sponsor_seek_chance: float = 0.5


func find_city(id: String) -> CityDefinition:
	for item in cities:
		if item.id == id:
			return item
	return null


func find_venue(id: String) -> VenueCategoryDefinition:
	for item in venues:
		if item.id == id:
			return item
	return null


func find_production(id: String) -> ProductionLevelDefinition:
	for item in production_levels:
		if item.id == id:
			return item
	return null


func find_addon(id: String) -> ProductionAddonDefinition:
	for item in addons:
		if item.id == id:
			return item
	return null


func find_crew_role(id: String) -> CrewRoleDefinition:
	for item in crew_roles:
		if item.id == id:
			return item
	return null


func find_product(id: String) -> MerchProductDefinition:
	for item in merch_products:
		if item.id == id:
			return item
	return null


func find_festival(id: String) -> FestivalDefinition:
	for item in festivals:
		if item.id == id:
			return item
	return null


func find_sponsor(id: String) -> SponsorDefinition:
	for item in sponsors:
		if item.id == id:
			return item
	return null


func find_tour_type(id: String) -> TourTypeDefinition:
	for item in tour_types:
		if item.id == id:
			return item
	return null
