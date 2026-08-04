import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_utils.dart';
import '../../../models/club_model.dart';
import '../../../models/player_model.dart';
import '../../clubs/ui/club_profile_screen.dart';
import '../../clubs/ui/create_club_screen.dart' show kCountryList;
import '../../tournaments/ui/tournaments_screen.dart';

const kCountries = [
  {'flag': '🇩🇪', 'name': 'Germany'},
  {'flag': '🇬🇷', 'name': 'Greece'},
  {'flag': '🇮🇹', 'name': 'Italy'},
  {'flag': '🇪🇸', 'name': 'Spain'},
  {'flag': '🇫🇷', 'name': 'France'},
  {'flag': '🇬🇧', 'name': 'England'},
  {'flag': '🇵🇹', 'name': 'Portugal'},
  {'flag': '🇳🇱', 'name': 'Netherlands'},
  {'flag': '🇧🇪', 'name': 'Belgium'},
  {'flag': '🇦🇹', 'name': 'Austria'},
  {'flag': '🇨🇭', 'name': 'Switzerland'},
  {'flag': '🇵🇱', 'name': 'Poland'},
  {'flag': '🇷🇴', 'name': 'Romania'},
  {'flag': '🇷🇸', 'name': 'Serbia'},
  {'flag': '🇭🇷', 'name': 'Croatia'},
  {'flag': '🇹🇷', 'name': 'Turkey'},
  {'flag': '🇺🇦', 'name': 'Ukraine'},
  {'flag': '🇸🇪', 'name': 'Sweden'},
  {'flag': '🇳🇴', 'name': 'Norway'},
  {'flag': '🇩🇰', 'name': 'Denmark'},
  {'flag': '🇨🇿', 'name': 'Czech Republic'},
  {'flag': '🇸🇰', 'name': 'Slovakia'},
  {'flag': '🇭🇺', 'name': 'Hungary'},
  {'flag': '🇧🇬', 'name': 'Bulgaria'},
  {'flag': '🇦🇱', 'name': 'Albania'},
  {'flag': '🇽🇰', 'name': 'Kosovo'},
  {'flag': '🇲🇰', 'name': 'North Macedonia'},
  {'flag': '🇸🇮', 'name': 'Slovenia'},
  {'flag': '🇧🇦', 'name': 'Bosnia'},
  {'flag': '🇲🇪', 'name': 'Montenegro'},
];

const kDefaultAssociations = <String, List<Map<String, String>>>{
  'GR': [
    {'id': 'eps_athinon', 'name': 'ΕΠΣ Αθηνών'},
    {'id': 'eps_peiraios', 'name': 'ΕΠΣ Πειραιά'},
    {'id': 'eps_thessalonikis', 'name': 'ΕΠΣ Θεσσαλονίκης'},
    {'id': 'eps_makedonias', 'name': 'ΕΠΣ Μακεδονίας'},
    {'id': 'eps_kritis', 'name': 'ΕΠΣ Κρήτης'},
    {'id': 'eps_thessalias', 'name': 'ΕΠΣ Θεσσαλίας'},
    {'id': 'eps_achaias', 'name': 'ΕΠΣ Αχαΐας'},
    {'id': 'eps_ipeirou', 'name': 'ΕΠΣ Ηπείρου'},
    {'id': 'eps_kentrikis_elladas', 'name': 'ΕΠΣ Κεντρικής Ελλάδας'},
    {'id': 'eps_aitoloakarnanias', 'name': 'ΕΠΣ Αιτωλοακαρνανίας'},
    {'id': 'eps_dytikis_makedonias', 'name': 'ΕΠΣ Δυτικής Μακεδονίας'},
    {'id': 'eps_anatolikis_makedonias', 'name': 'ΕΠΣ Ανατολικής Μακεδονίας & Θράκης'},
    {'id': 'eps_kerkyras', 'name': 'ΕΠΣ Κέρκυρας'},
    {'id': 'eps_lesvou', 'name': 'ΕΠΣ Λέσβου'},
    {'id': 'eps_rodou', 'name': 'ΕΠΣ Ρόδου'},
    {'id': 'eps_nison', 'name': 'ΕΠΣ Νήσων'},
  ],
  'CY': [
    {'id': 'cy_lefkosias', 'name': 'ΠΟΛ Λευκωσίας'},
    {'id': 'cy_lemesou', 'name': 'ΠΟΛ Λεμεσού'},
    {'id': 'cy_larnakas', 'name': 'ΠΟΛ Λάρνακας'},
    {'id': 'cy_pafou', 'name': 'ΠΟΛ Πάφου'},
    {'id': 'cy_ammochostou', 'name': 'ΠΟΛ Αμμοχώστου'},
  ],
  'DE': [
    {'id': 'de_bfv', 'name': 'Bayerischer Fußball-Verband (BFV)'},
    {'id': 'de_nfv', 'name': 'Niedersächsischer Fußballverband (NFV)'},
    {'id': 'de_hfv', 'name': 'Hamburger Fußball-Verband (HFV)'},
    {'id': 'de_bfv_berlin', 'name': 'Berliner Fußball-Verband'},
    {'id': 'de_wdfv', 'name': 'Westdeutscher Fußball-Verband (WDFV)'},
    {'id': 'de_nofv', 'name': 'Nordostdeutscher Fußballverband (NOFV)'},
    {'id': 'de_swfv', 'name': 'Südwestdeutscher Fußballverband (SWFV)'},
    {'id': 'de_sfv', 'name': 'Sächsischer Fußball-Verband (SFV)'},
    {'id': 'de_bfv_bw', 'name': 'Badischer Fußballverband'},
    {'id': 'de_wfv', 'name': 'Württembergischer Fußballverband (WFV)'},
  ],
  'GB': [
    {'id': 'gb_london_fa', 'name': 'London FA'},
    {'id': 'gb_manchester_fa', 'name': 'Manchester FA'},
    {'id': 'gb_west_riding_fa', 'name': 'West Riding FA'},
    {'id': 'gb_birmingham_fa', 'name': 'Birmingham County FA'},
    {'id': 'gb_middlesex_fa', 'name': 'Middlesex FA'},
    {'id': 'gb_kent_fa', 'name': 'Kent FA'},
    {'id': 'gb_surrey_fa', 'name': 'Surrey FA'},
    {'id': 'gb_liverpool_fa', 'name': 'Liverpool County FA'},
    {'id': 'gb_sheffield_fa', 'name': 'Sheffield & Hallamshire FA'},
  ],
  'ES': [
    {'id': 'es_rfm', 'name': 'Federación Madrileña de Fútbol'},
    {'id': 'es_fcf', 'name': 'Federació Catalana de Futbol'},
    {'id': 'es_fvf', 'name': 'Federación Valenciana de Fútbol'},
    {'id': 'es_faf', 'name': 'Federación Andaluza de Fútbol'},
    {'id': 'es_rfvf', 'name': 'Real Federación Vasca de Fútbol'},
    {'id': 'es_fgf', 'name': 'Federación Gallega de Fútbol'},
    {'id': 'es_ffib', 'name': 'Federació de Futbol de les Illes Balears'},
  ],
  'IT': [
    {'id': 'it_lombardia', 'name': 'CR Lombardia (LND)'},
    {'id': 'it_lazio', 'name': 'CR Lazio (LND)'},
    {'id': 'it_campania', 'name': 'CR Campania (LND)'},
    {'id': 'it_sicilia', 'name': 'CR Sicilia (LND)'},
    {'id': 'it_veneto', 'name': 'CR Veneto (LND)'},
    {'id': 'it_piemonte', 'name': 'CR Piemonte Valle d\'Aosta (LND)'},
    {'id': 'it_toscana', 'name': 'CR Toscana (LND)'},
    {'id': 'it_emilia', 'name': 'CR Emilia Romagna (LND)'},
  ],
  'FR': [
    {'id': 'fr_idf', 'name': 'Ligue Paris Île-de-France de Football'},
    {'id': 'fr_med', 'name': 'Ligue de Football de Méditerranée'},
    {'id': 'fr_aqt', 'name': 'Ligue de Football d\'Aquitaine'},
    {'id': 'fr_ara', 'name': 'Ligue Auvergne-Rhône-Alpes de Football'},
    {'id': 'fr_nor', 'name': 'Ligue de Football de Normandie'},
    {'id': 'fr_hdf', 'name': 'Ligue des Hauts-de-France de Football'},
    {'id': 'fr_bre', 'name': 'Ligue de Bretagne de Football'},
  ],
  'PT': [
    {'id': 'pt_afl', 'name': 'Associação de Futebol de Lisboa (AFL)'},
    {'id': 'pt_afp', 'name': 'Associação de Futebol do Porto (AFP)'},
    {'id': 'pt_afb', 'name': 'Associação de Futebol de Braga (AFB)'},
    {'id': 'pt_afs', 'name': 'Associação de Futebol de Setúbal (AFS)'},
    {'id': 'pt_afc', 'name': 'Associação de Futebol de Coimbra (AFC)'},
    {'id': 'pt_afav', 'name': 'Associação de Futebol de Aveiro (AFAV)'},
  ],
  'NL': [
    {'id': 'nl_oost', 'name': 'KNVB Amateurvoetbal Oost'},
    {'id': 'nl_west1', 'name': 'KNVB Amateurvoetbal West I'},
    {'id': 'nl_west2', 'name': 'KNVB Amateurvoetbal West II'},
    {'id': 'nl_noord', 'name': 'KNVB Amateurvoetbal Noord'},
    {'id': 'nl_zuid1', 'name': 'KNVB Amateurvoetbal Zuid I'},
    {'id': 'nl_zuid2', 'name': 'KNVB Amateurvoetbal Zuid II'},
  ],
  'BE': [
    {'id': 'be_vv', 'name': 'Voetbal Vlaanderen'},
    {'id': 'be_acff', 'name': 'ACFF (Association des Clubs Francophones de Football)'},
    {'id': 'be_rfcb', 'name': 'Royal Football Club de Bruxelles'},
  ],
  'AT': [
    {'id': 'at_wien', 'name': 'Wiener Fußballverband'},
    {'id': 'at_oefb_stmk', 'name': 'Steirischer Fußballverband'},
    {'id': 'at_oefb_ooe', 'name': 'OÖ Fußballverband'},
    {'id': 'at_oefb_tir', 'name': 'Tiroler Fußballverband'},
    {'id': 'at_oefb_sbg', 'name': 'Salzburger Fußballverband'},
  ],
  'CH': [
    {'id': 'ch_afm', 'name': 'Association de Football du Mittelland'},
    {'id': 'ch_asvz', 'name': 'Verband Zentralschweiz'},
    {'id': 'ch_asf_rom', 'name': 'ASF Région Romande'},
    {'id': 'ch_sfv_ost', 'name': 'Regionalverband Ostschweiz'},
  ],
  'PL': [
    {'id': 'pl_mazowiecka', 'name': 'Mazowiecki ZPN'},
    {'id': 'pl_slaska', 'name': 'Śląski ZPN'},
    {'id': 'pl_malopolska', 'name': 'Małopolski ZPN'},
    {'id': 'pl_wielkopolska', 'name': 'Wielkopolski ZPN'},
    {'id': 'pl_podkarpacie', 'name': 'Podkarpacki ZPN'},
  ],
  'RO': [
    {'id': 'ro_bucuresti', 'name': 'AJF București'},
    {'id': 'ro_cluj', 'name': 'AJF Cluj'},
    {'id': 'ro_iasi', 'name': 'AJF Iași'},
    {'id': 'ro_timis', 'name': 'AJF Timiș'},
    {'id': 'ro_constanta', 'name': 'AJF Constanța'},
  ],
  'RS': [
    {'id': 'rs_belgrade', 'name': 'FS Beograda'},
    {'id': 'rs_vojvodina', 'name': 'FS Vojvodine'},
    {'id': 'rs_sumadija', 'name': 'FS Šumadije i Zapadne Srbije'},
    {'id': 'rs_istocna', 'name': 'FS Istočne Srbije'},
  ],
  'HR': [
    {'id': 'hr_zagreb', 'name': 'NŠ Zagreb'},
    {'id': 'hr_split', 'name': 'NŠ Split'},
    {'id': 'hr_rijeka', 'name': 'NŠ Rijeka'},
    {'id': 'hr_osijek', 'name': 'NŠ Osijek'},
  ],
  'TR': [
    {'id': 'tr_istanbul', 'name': 'İstanbul İl Futbol Federasyonu'},
    {'id': 'tr_ankara', 'name': 'Ankara İl Futbol Federasyonu'},
    {'id': 'tr_izmir', 'name': 'İzmir İl Futbol Federasyonu'},
    {'id': 'tr_bursa', 'name': 'Bursa İl Futbol Federasyonu'},
    {'id': 'tr_antalya', 'name': 'Antalya İl Futbol Federasyonu'},
    {'id': 'tr_adana', 'name': 'Adana İl Futbol Federasyonu'},
  ],
  'UA': [
    {'id': 'ua_kyiv', 'name': 'ФФ Київської області'},
    {'id': 'ua_kharkiv', 'name': 'ФФ Харківської області'},
    {'id': 'ua_dnipro', 'name': 'ФФ Дніпропетровської області'},
    {'id': 'ua_odessa', 'name': 'ФФ Одеської області'},
    {'id': 'ua_lviv', 'name': 'ФФ Львівської області'},
  ],
  'SE': [
    {'id': 'se_stockholm', 'name': 'Stockholms FF'},
    {'id': 'se_skane', 'name': 'Skånska FF'},
    {'id': 'se_vastra', 'name': 'Västra Götalands FF'},
    {'id': 'se_ostergotland', 'name': 'Östergötlands FF'},
  ],
  'NO': [
    {'id': 'no_oslo', 'name': 'Oslo Fotballkrets'},
    {'id': 'no_hordaland', 'name': 'Hordaland Fotballkrets'},
    {'id': 'no_rogaland', 'name': 'Rogaland Fotballkrets'},
    {'id': 'no_akershus', 'name': 'Akershus Fotballkrets'},
  ],
  'DK': [
    {'id': 'dk_kobenhavn', 'name': 'Københavns Boldspil-Union (KBU)'},
    {'id': 'dk_jylland', 'name': 'Jyllands-Posten BU'},
    {'id': 'dk_fyn', 'name': 'Fyns Boldspil-Union'},
    {'id': 'dk_bornholm', 'name': 'Bornholms Boldspil-Union'},
  ],
  'CZ': [
    {'id': 'cz_prag', 'name': 'Pražský fotbalový svaz'},
    {'id': 'cz_jihomoravsky', 'name': 'Jihomoravský KFS'},
    {'id': 'cz_stredocesky', 'name': 'Středočeský KFS'},
    {'id': 'cz_moravskoslezsky', 'name': 'Moravskoslezský KFS'},
  ],
  'SK': [
    {'id': 'sk_bratislava', 'name': 'BFZ Bratislava'},
    {'id': 'sk_zapadoslovensky', 'name': 'ZsFZ Západoslovenský'},
    {'id': 'sk_stredoslovensky', 'name': 'SsFZ Stredoslovenský'},
    {'id': 'sk_vychod', 'name': 'VsFZ Východoslovenský'},
  ],
  'HU': [
    {'id': 'hu_budapest', 'name': 'BLSZ Budapest'},
    {'id': 'hu_pest', 'name': 'Pest Megye MLSz'},
    {'id': 'hu_borsod', 'name': 'Borsod-Abaúj-Zemplén MLSz'},
    {'id': 'hu_gyor', 'name': 'Győr-Moson-Sopron MLSz'},
  ],
  'BG': [
    {'id': 'bg_sofia', 'name': 'СОФИЙСКИ ФУТБОЛЕН СЪЮЗ'},
    {'id': 'bg_plovdiv', 'name': 'ПЛОВДИВСКИ ФУТБОЛЕН СЪЮЗ'},
    {'id': 'bg_varna', 'name': 'ВАРНЕНСКИ ФУТБОЛЕН СЪЮЗ'},
    {'id': 'bg_burgas', 'name': 'БУРГАСКИ ФУТБОЛЕН СЪЮЗ'},
  ],
  'AL': [
    {'id': 'al_tirane', 'name': 'FSHF Tiranës'},
    {'id': 'al_durres', 'name': 'FSHF Durrësit'},
    {'id': 'al_shkoder', 'name': 'FSHF Shkodrës'},
  ],
  'XK': [
    {'id': 'xk_prishtine', 'name': 'Prishtina FF'},
    {'id': 'xk_prizren', 'name': 'Prizren FF'},
    {'id': 'xk_peje', 'name': 'Peja FF'},
  ],
  'MK': [
    {'id': 'mk_skopje', 'name': 'ФФС Скопје'},
    {'id': 'mk_bitola', 'name': 'ФФС Битола'},
    {'id': 'mk_tetovo', 'name': 'ФФС Тетово'},
  ],
  'SI': [
    {'id': 'si_ljubljana', 'name': 'NZS Ljubljana'},
    {'id': 'si_maribor', 'name': 'NZS Maribor'},
    {'id': 'si_celje', 'name': 'NZS Celje'},
  ],
  'BA': [
    {'id': 'ba_sarajevo', 'name': 'NFSBiH Sarajevo'},
    {'id': 'ba_banja_luka', 'name': 'FSRS Banja Luka'},
    {'id': 'ba_mostar', 'name': 'HNSBiH Mostar'},
  ],
  'ME': [
    {'id': 'me_podgorica', 'name': 'FSCG Podgorice'},
    {'id': 'me_niksic', 'name': 'FSCG Nikšića'},
    {'id': 'me_bar', 'name': 'FSCG Bara'},
  ],
};

const kDefaultCompetitions = <String, List<Map<String, String>>>{
  // ΕΠΣ Αθηνών
  'eps_athinon': [
    {'id': 'eps_ath_a', 'name': "Α' Ερασιτεχνική Αθηνών", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ath_b1', 'name': "Β' Κατηγορία Αθηνών (Α' Όμιλος)", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ath_b2', 'name': "Β' Κατηγορία Αθηνών (Β' Όμιλος)", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ath_c', 'name': "Γ' Κατηγορία Αθηνών", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ath_cup', 'name': 'Κύπελλο ΕΠΣ Αθηνών', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ath_w', 'name': "Α' Κατηγορία Γυναικών Αθηνών", 'season': '2024-2025', 'gender': 'women'},
  ],
  // ΕΠΣ Πειραιά
  'eps_peiraios': [
    {'id': 'eps_pei_a', 'name': "Α' Κατηγορία Πειραιά", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_pei_b1', 'name': "Β' Κατηγορία Πειραιά (Α' Όμιλος)", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_pei_b2', 'name': "Β' Κατηγορία Πειραιά (Β' Όμιλος)", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_pei_c', 'name': "Γ' Κατηγορία Πειραιά", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_pei_cup', 'name': 'Κύπελλο ΕΠΣ Πειραιά', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Θεσσαλονίκης
  'eps_thessalonikis': [
    {'id': 'eps_thes_a', 'name': "Α' Ερασιτεχνική Θεσσαλονίκης", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_thes_b1', 'name': "Β' Κατηγορία Θεσσαλονίκης (Α' Όμιλος)", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_thes_b2', 'name': "Β' Κατηγορία Θεσσαλονίκης (Β' Όμιλος)", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_thes_c', 'name': "Γ' Κατηγορία Θεσσαλονίκης", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_thes_cup', 'name': 'Κύπελλο ΕΠΣ Θεσσαλονίκης', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Μακεδονίας
  'eps_makedonias': [
    {'id': 'eps_mak_a', 'name': "Α' Κατηγορία Μακεδονίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_mak_b', 'name': "Β' Κατηγορία Μακεδονίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_mak_c', 'name': "Γ' Κατηγορία Μακεδονίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_mak_cup', 'name': 'Κύπελλο ΕΠΣ Μακεδονίας', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Κρήτης
  'eps_kritis': [
    {'id': 'eps_kri_a', 'name': "Α' Κατηγορία Κρήτης", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_kri_b1', 'name': "Β' Κατηγορία Κρήτης (Ανατολικά)", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_kri_b2', 'name': "Β' Κατηγορία Κρήτης (Δυτικά)", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_kri_c', 'name': "Γ' Κατηγορία Κρήτης", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_kri_cup', 'name': 'Κύπελλο ΕΠΣ Κρήτης', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Θεσσαλίας
  'eps_thessalias': [
    {'id': 'eps_thl_a', 'name': "Α' Κατηγορία Θεσσαλίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_thl_b', 'name': "Β' Κατηγορία Θεσσαλίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_thl_c', 'name': "Γ' Κατηγορία Θεσσαλίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_thl_cup', 'name': 'Κύπελλο ΕΠΣ Θεσσαλίας', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Αχαΐας
  'eps_achaias': [
    {'id': 'eps_ach_a', 'name': "Α' Κατηγορία Αχαΐας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ach_b', 'name': "Β' Κατηγορία Αχαΐας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ach_c', 'name': "Γ' Κατηγορία Αχαΐας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ach_cup', 'name': 'Κύπελλο ΕΠΣ Αχαΐας', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Ηπείρου
  'eps_ipeirou': [
    {'id': 'eps_ipe_a', 'name': "Α' Κατηγορία Ηπείρου", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ipe_b', 'name': "Β' Κατηγορία Ηπείρου", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ipe_cup', 'name': 'Κύπελλο ΕΠΣ Ηπείρου', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Κεντρικής Ελλάδας
  'eps_kentrikis_elladas': [
    {'id': 'eps_ken_a', 'name': "Α' Κατηγορία Κεντρικής Ελλάδας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ken_b', 'name': "Β' Κατηγορία Κεντρικής Ελλάδας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ken_cup', 'name': 'Κύπελλο ΕΠΣ Κεντρικής Ελλάδας', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Αιτωλοακαρνανίας
  'eps_aitoloakarnanias': [
    {'id': 'eps_ait_a', 'name': "Α' Κατηγορία Αιτωλοακαρνανίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ait_b', 'name': "Β' Κατηγορία Αιτωλοακαρνανίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ait_cup', 'name': 'Κύπελλο ΕΠΣ Αιτωλοακαρνανίας', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Δυτικής Μακεδονίας
  'eps_dytikis_makedonias': [
    {'id': 'eps_dym_a', 'name': "Α' Κατηγορία Δυτικής Μακεδονίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_dym_b', 'name': "Β' Κατηγορία Δυτικής Μακεδονίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_dym_cup', 'name': 'Κύπελλο ΕΠΣ Δυτικής Μακεδονίας', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Ανατολικής Μακεδονίας & Θράκης
  'eps_anatolikis_makedonias': [
    {'id': 'eps_anm_a', 'name': "Α' Κατηγορία Ανατολικής Μακεδονίας & Θράκης", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_anm_b', 'name': "Β' Κατηγορία Ανατολικής Μακεδονίας & Θράκης", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_anm_cup', 'name': 'Κύπελλο ΕΠΣ Ανατολικής Μακεδονίας', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Κέρκυρας
  'eps_kerkyras': [
    {'id': 'eps_ker_a', 'name': "Α' Κατηγορία Κέρκυρας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ker_b', 'name': "Β' Κατηγορία Κέρκυρας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_ker_cup', 'name': 'Κύπελλο ΕΠΣ Κέρκυρας', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Λέσβου
  'eps_lesvou': [
    {'id': 'eps_les_a', 'name': "Α' Κατηγορία Λέσβου", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_les_b', 'name': "Β' Κατηγορία Λέσβου", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_les_cup', 'name': 'Κύπελλο ΕΠΣ Λέσβου', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Ρόδου
  'eps_rodou': [
    {'id': 'eps_rod_a', 'name': "Α' Κατηγορία Ρόδου", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_rod_b', 'name': "Β' Κατηγορία Ρόδου", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_rod_cup', 'name': 'Κύπελλο ΕΠΣ Ρόδου', 'season': '2024-2025', 'gender': 'men'},
  ],
  // ΕΠΣ Νήσων
  'eps_nison': [
    {'id': 'eps_nis_a', 'name': "Α' Κατηγορία Νήσων", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_nis_b', 'name': "Β' Κατηγορία Νήσων", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'eps_nis_cup', 'name': 'Κύπελλο ΕΠΣ Νήσων', 'season': '2024-2025', 'gender': 'men'},
  ],
  // Κύπρος
  'cy_lefkosias': [
    {'id': 'cy_lef_a', 'name': "Α' Κατηγορία Λευκωσίας", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'cy_lef_b', 'name': "Β' Κατηγορία Λευκωσίας", 'season': '2024-2025', 'gender': 'men'},
  ],
  'cy_lemesou': [
    {'id': 'cy_lem_a', 'name': "Α' Κατηγορία Λεμεσού", 'season': '2024-2025', 'gender': 'men'},
    {'id': 'cy_lem_b', 'name': "Β' Κατηγορία Λεμεσού", 'season': '2024-2025', 'gender': 'men'},
  ],
  // Γερμανία
  'de_bfv': [
    {'id': 'de_bfv_1', 'name': 'Bayernliga', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'de_bfv_2', 'name': 'Landesliga Bayern', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'de_bfv_3', 'name': 'Bezirksliga', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'de_bfv_4', 'name': 'Kreisliga', 'season': '2024-2025', 'gender': 'men'},
  ],
  'de_wdfv': [
    {'id': 'de_wdfv_1', 'name': 'Niederrheinliga', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'de_wdfv_2', 'name': 'Landesliga Niederrhein', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'de_wdfv_3', 'name': 'Bezirksliga', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'de_wdfv_4', 'name': 'Kreisliga', 'season': '2024-2025', 'gender': 'men'},
  ],
  // Αγγλία
  'gb_london_fa': [
    {'id': 'gb_lon_1', 'name': 'London Senior Cup', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'gb_lon_2', 'name': 'London Intermediate Cup', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'gb_lon_3', 'name': 'London Junior Cup', 'season': '2024-2025', 'gender': 'men'},
  ],
  'gb_manchester_fa': [
    {'id': 'gb_man_1', 'name': 'Manchester FA County Cup', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'gb_man_2', 'name': 'Manchester Amateur League', 'season': '2024-2025', 'gender': 'men'},
  ],
  // Ισπανία
  'es_rfm': [
    {'id': 'es_rfm_1', 'name': 'Primera Autonómica Madrid', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'es_rfm_2', 'name': 'Primera Regional Madrid', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'es_rfm_3', 'name': 'Segunda Regional Madrid', 'season': '2024-2025', 'gender': 'men'},
  ],
  'es_fcf': [
    {'id': 'es_fcf_1', 'name': 'Primera Catalana', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'es_fcf_2', 'name': 'Segona Catalana', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'es_fcf_3', 'name': 'Tercera Catalana', 'season': '2024-2025', 'gender': 'men'},
  ],
  // Ιταλία
  'it_lombardia': [
    {'id': 'it_lom_1', 'name': 'Eccellenza Lombardia', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'it_lom_2', 'name': 'Promozione Lombardia', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'it_lom_3', 'name': 'Prima Categoria Lombardia', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'it_lom_4', 'name': 'Seconda Categoria Lombardia', 'season': '2024-2025', 'gender': 'men'},
  ],
  'it_lazio': [
    {'id': 'it_laz_1', 'name': 'Eccellenza Lazio', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'it_laz_2', 'name': 'Promozione Lazio', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'it_laz_3', 'name': 'Prima Categoria Lazio', 'season': '2024-2025', 'gender': 'men'},
  ],
  // Γαλλία
  'fr_idf': [
    {'id': 'fr_idf_1', 'name': 'Régional 1 Île-de-France', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'fr_idf_2', 'name': 'Régional 2 Île-de-France', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'fr_idf_3', 'name': 'Régional 3 Île-de-France', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'fr_idf_4', 'name': 'Départemental 1 Île-de-France', 'season': '2024-2025', 'gender': 'men'},
  ],
  // Πορτογαλία
  'pt_afl': [
    {'id': 'pt_afl_1', 'name': 'Campeonato de Lisboa', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'pt_afl_2', 'name': 'Primeira Divisão Lisboa', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'pt_afl_3', 'name': 'Segunda Divisão Lisboa', 'season': '2024-2025', 'gender': 'men'},
  ],
  // Ολλανδία
  'nl_oost': [
    {'id': 'nl_oost_1', 'name': 'Hoofdklasse Oost', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'nl_oost_2', 'name': 'Eerste Klasse Oost', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'nl_oost_3', 'name': 'Tweede Klasse Oost', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'nl_oost_4', 'name': 'Derde Klasse Oost', 'season': '2024-2025', 'gender': 'men'},
  ],
  'nl_west1': [
    {'id': 'nl_w1_1', 'name': 'Hoofdklasse West I', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'nl_w1_2', 'name': 'Eerste Klasse West I', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'nl_w1_3', 'name': 'Tweede Klasse West I', 'season': '2024-2025', 'gender': 'men'},
  ],
  // Τουρκία
  'tr_istanbul': [
    {'id': 'tr_ist_1', 'name': 'İstanbul Amatör Ligi 1', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'tr_ist_2', 'name': 'İstanbul Amatör Ligi 2', 'season': '2024-2025', 'gender': 'men'},
    {'id': 'tr_ist_3', 'name': 'İstanbul Amatör Ligi 3', 'season': '2024-2025', 'gender': 'men'},
  ],
};

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Teams'),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Browse'),
            Tab(text: 'Search'),
            Tab(text: 'Standings'),
            Tab(text: 'Τουρνουά'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _BrowseTab(),
          _SearchTab(),
          _StandingsTab(),
          TournamentsScreen(showAppBar: false),
        ],
      ),
    );
  }
}

// ─── BROWSE TAB ───────────────────────────────────────────────────────────────

class _BrowseTab extends StatefulWidget {
  const _BrowseTab();

  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    final myClubId = user?.clubId;

    final filtered = kCountries
        .where((c) => c['name']!.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search country...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
            color: AppTheme.primaryLight,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (myClubId != null) ...[
                  _MyClubCard(clubId: myClubId),
                  const SizedBox(height: 16),
                ],
                ...filtered.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CountryTile(flag: c['flag']!, country: c['name']!),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MyClubCard extends StatelessWidget {
  final String clubId;
  const _MyClubCard({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final club = ClubModel.fromMap(
          snap.data!.data() as Map<String, dynamic>,
          clubId,
        );
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: clubId)),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF0D2B56)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.supportGreen.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg2,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.supportGreen, width: 2),
                    image: safeNetworkImage(club.logoUrl) != null
                        ? DecorationImage(
                            image: safeNetworkImage(club.logoUrl)!,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: safeNetworkImage(club.logoUrl) == null
                      ? const Icon(Icons.sports_soccer,
                          color: AppTheme.supportGreen, size: 28)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.supportGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'MY CLUB',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        club.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${club.city} • ${club.league}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── SEARCH TAB ───────────────────────────────────────────────────────────────

class _SearchTab extends StatefulWidget {
  const _SearchTab();

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  String _query = '';
  bool _searchClubs = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _searchClubs ? 'Search clubs...' : 'Search players...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ToggleChip(
                    label: 'Clubs',
                    selected: _searchClubs,
                    onTap: () => setState(() => _searchClubs = true),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: 'Players',
                    selected: !_searchClubs,
                    onTap: () => setState(() => _searchClubs = false),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _query.length < 2
              ? const Center(
                  child: Text(
                    'Type at least 2 characters to search...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : _searchClubs
                  ? _ClubResults(query: _query)
                  : _PlayerResults(query: _query),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primaryLight : AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ClubResults extends StatelessWidget {
  final String query;
  const _ClubResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final queryLower = query.toLowerCase();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('\u03a3\u03c6\u03ac\u03bb\u03bc\u03b1: ${snap.error}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final clubs = (snap.data?.docs ?? [])
            .map((d) => ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((c) =>
                c.name.toLowerCase().contains(queryLower) ||
                c.city.toLowerCase().contains(queryLower))
            .take(30)
            .toList();
        if (clubs.isEmpty) {
          return Center(
            child: Text(
              'No clubs found for "$query"',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: clubs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _ClubListTile(club: clubs[i], rank: i + 1),
        );
      },
    );
  }
}

class _PlayerResults extends StatelessWidget {
  final String query;
  const _PlayerResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final queryLower = query.toLowerCase();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('players')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('\u03a3\u03c6\u03ac\u03bb\u03bc\u03b1: ${snap.error}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final players = (snap.data?.docs ?? [])
            .map((d) => PlayerModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((p) => p.isActive && p.name.toLowerCase().contains(queryLower))
            .take(50)
            .toList();
        if (players.isEmpty) {
          return Center(
            child: Text(
              'No players found for "$query"',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: players.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _PlayerResultTile(player: players[i]),
        );
      },
    );
  }
}

class _PlayerResultTile extends StatelessWidget {
  final PlayerModel player;
  const _PlayerResultTile({required this.player});

  Color _posColor(String pos) {
    switch (pos) {
      case 'GK': return AppTheme.accent;
      case 'DEF': return AppTheme.primaryLight;
      case 'MID': return AppTheme.supportGreen;
      case 'FWD': return AppTheme.liveRed;
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _posColor(player.position);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                player.number != null ? '#${player.number}' : player.position,
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  player.positionLabel,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (player.nationality != null)
            Text(player.nationality!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── STANDINGS TAB ────────────────────────────────────────────────────────────

class _StandingsTab extends StatefulWidget {
  const _StandingsTab();

  @override
  State<_StandingsTab> createState() => _StandingsTabState();
}

class _StandingsTabState extends State<_StandingsTab> {
  String _country = kCountryList.first;
  String _category = kCategories.first;
  String? _assocId;

  @override
  Widget build(BuildContext context) {
    final countryCode = _kCountryToCode[_country] ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: DropdownButton<String>(
                  value: _country,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardBg,
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.expand_more, color: AppTheme.textSecondary),
                  items: kCountryList
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _country = v!;
                    _assocId = null;
                  }),
                ),
              ),
              const SizedBox(height: 8),
              // Association dropdown (only if associations exist for country)
              if (countryCode.isNotEmpty)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('associations')
                      .where('countryCode', isEqualTo: countryCode)
                      .snapshots(),
                  builder: (ctx, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: DropdownButton<String?>(
                            value: _assocId,
                            isExpanded: true,
                            dropdownColor: AppTheme.cardBg,
                            style: const TextStyle(color: Colors.white),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.expand_more, color: AppTheme.textSecondary),
                            hint: const Text('Όλες οι ενώσεις', style: TextStyle(color: AppTheme.textSecondary)),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Όλες οι ενώσεις', style: TextStyle(color: AppTheme.textSecondary)),
                              ),
                              ...docs.map((d) {
                                final name = (d.data() as Map<String, dynamic>)['name'] as String? ?? d.id;
                                return DropdownMenuItem<String?>(value: d.id, child: Text(name));
                              }),
                            ],
                            onChanged: (v) => setState(() { _assocId = v; }),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              // Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kCategories.map((cat) {
                    final sel = _category == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primaryLight : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? AppTheme.primaryLight : AppTheme.divider,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: sel ? Colors.white : AppTheme.textSecondary,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: _StandingsList(
            country: _country,
            category: _category,
            assocId: _assocId,
          ),
        ),
      ],
    );
  }
}

class _StandingsList extends StatelessWidget {
  final String country;
  final String category;
  final String? assocId;
  const _StandingsList({required this.country, required this.category, this.assocId});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('clubs')
        .where('country', isEqualTo: country)
        .where('category', isEqualTo: category);
    if (assocId != null) {
      query = query.where('assocId', isEqualTo: assocId);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text('Σφάλμα φόρτωσης', style: const TextStyle(color: Colors.red)),
          );
        }
        final clubs = (snap.data?.docs ?? [])
            .map((d) => ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList()
          ..sort((a, b) {
            final ptDiff = b.points.compareTo(a.points);
            if (ptDiff != 0) return ptDiff;
            final gdDiff = b.goalDiff.compareTo(a.goalDiff);
            if (gdDiff != 0) return gdDiff;
            return b.goalsFor.compareTo(a.goalsFor);
          });

        if (clubs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined, size: 64, color: AppTheme.cardBg2),
                const SizedBox(height: 12),
                Text(
                  'No clubs in $country / $category',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Clubs can register and select their category',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 28, child: Text('#', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(child: Text('Club', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                    SizedBox(width: 28, child: Center(child: Text('P', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)))),
                    SizedBox(width: 28, child: Center(child: Text('W', style: TextStyle(color: AppTheme.supportGreen, fontSize: 11, fontWeight: FontWeight.bold)))),
                    SizedBox(width: 28, child: Center(child: Text('D', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)))),
                    SizedBox(width: 28, child: Center(child: Text('L', style: TextStyle(color: AppTheme.red, fontSize: 11, fontWeight: FontWeight.bold)))),
                    SizedBox(width: 32, child: Center(child: Text('GD', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)))),
                    SizedBox(width: 32, child: Center(child: Text('Pts', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: clubs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) => _StandingRow(club: clubs[i], rank: i + 1),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StandingRow extends StatelessWidget {
  final ClubModel club;
  final int rank;
  const _StandingRow({required this.club, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColors = [AppTheme.accent, Colors.grey[400]!, Colors.brown[400]!];
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: club.id)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppTheme.navyGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTop3 ? rankColors[rank - 1].withValues(alpha: 0.4) : AppTheme.divider,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: isTop3 ? rankColors[rank - 1] : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                shape: BoxShape.circle,
                image: safeNetworkImage(club.logoUrl) != null
                    ? DecorationImage(image: safeNetworkImage(club.logoUrl)!, fit: BoxFit.cover)
                    : null,
              ),
              child: safeNetworkImage(club.logoUrl) == null
                  ? const Icon(Icons.sports_soccer, color: AppTheme.primaryLight, size: 16)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(club.city, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            SizedBox(width: 28, child: Center(child: Text('${club.played}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)))),
            SizedBox(width: 28, child: Center(child: Text('${club.wins}', style: const TextStyle(color: AppTheme.supportGreen, fontSize: 13, fontWeight: FontWeight.bold)))),
            SizedBox(width: 28, child: Center(child: Text('${club.draws}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)))),
            SizedBox(width: 28, child: Center(child: Text('${club.losses}', style: const TextStyle(color: AppTheme.red, fontSize: 13)))),
            SizedBox(width: 32, child: Center(child: Text(
              club.goalDiff >= 0 ? '+${club.goalDiff}' : '${club.goalDiff}',
              style: TextStyle(
                color: club.goalDiff > 0 ? AppTheme.supportGreen : club.goalDiff < 0 ? AppTheme.red : AppTheme.textSecondary,
                fontSize: 12,
              ),
            ))),
            SizedBox(width: 32, child: Center(child: Text('${club.points}', style: const TextStyle(color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.w900)))),
          ],
        ),
      ),
    );
  }
}

// ─── REUSED WIDGETS ───────────────────────────────────────────────────────────

class _CountryTile extends StatelessWidget {
  final String flag;
  final String country;
  const _CountryTile({required this.flag, required this.country});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CountryClubsScreen(country: country, flag: flag),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.navyGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  country,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .where('country', isEqualTo: country)
                    .snapshots(),
                builder: (_, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  if (count == 0) {
                    return const Icon(Icons.chevron_right, color: AppTheme.textSecondary);
                  }
                  return Row(
                    children: [
                      Text('$count', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(width: 2),
                      const Text('clubs', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _kCountryToCode = {
  'Greece': 'GR', 'Germany': 'DE', 'England': 'GB', 'Spain': 'ES',
  'Italy': 'IT', 'France': 'FR', 'Portugal': 'PT', 'Netherlands': 'NL',
  'Turkey': 'TR', 'Cyprus': 'CY', 'Belgium': 'BE', 'Austria': 'AT',
  'Switzerland': 'CH', 'Poland': 'PL', 'Romania': 'RO', 'Serbia': 'RS',
  'Croatia': 'HR', 'Ukraine': 'UA', 'Sweden': 'SE', 'Norway': 'NO',
  'Denmark': 'DK', 'Czech Republic': 'CZ', 'Slovakia': 'SK', 'Hungary': 'HU',
  'Bulgaria': 'BG', 'Albania': 'AL', 'Kosovo': 'XK', 'North Macedonia': 'MK',
  'Slovenia': 'SI', 'Bosnia': 'BA', 'Montenegro': 'ME',
};

const _kTeamFilters = ['All', 'Α΄ Ομάδα', 'Β΄ Ομάδα', 'Γυναικεία', 'Ακαδημίες'];

class CountryClubsScreen extends StatefulWidget {
  final String country;
  final String flag;
  const CountryClubsScreen({super.key, required this.country, required this.flag});

  @override
  State<CountryClubsScreen> createState() => _CountryClubsScreenState();
}

class _CountryClubsScreenState extends State<CountryClubsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('${widget.flag} ${widget.country}'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _kTeamFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final f = _kTeamFilters[i];
                final selected = _filter == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: selected,
                  selectedColor: AppTheme.primaryLight,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _filter = f),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clubs')
                  .where('country', isEqualTo: widget.country)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = (snap.data?.docs ?? [])
                    .map((d) => ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                    .toList()
                  ..sort((a, b) => b.votes.compareTo(a.votes));
                final clubs = _filter == 'All'
                    ? all
                    : _filter == 'Ακαδημίες'
                        ? all.where((c) => c.academiesCount > 0).toList()
                        : all.where((c) => c.category == _filter).toList();
                final countryCode = _kCountryToCode[widget.country] ?? '';
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (countryCode.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _AssociationsSection(
                          countryCode: countryCode,
                          flag: widget.flag,
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          'ΣΥΛΛΟΓΟΙ',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    if (clubs.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Text(widget.flag, style: const TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              const Text(
                                'No clubs in this category',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.separated(
                          itemCount: clubs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) => _ClubListTile(club: clubs[i], rank: i + 1),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubListTile extends StatelessWidget {
  final ClubModel club;
  final int rank;
  const _ClubListTile({required this.club, required this.rank});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: club.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.navyGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#$rank',
                style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                shape: BoxShape.circle,
                image: safeNetworkImage(club.logoUrl) != null
                    ? DecorationImage(image: safeNetworkImage(club.logoUrl)!, fit: BoxFit.cover)
                    : null,
              ),
              child: safeNetworkImage(club.logoUrl) == null
                  ? const Icon(Icons.sports_soccer, color: AppTheme.primaryLight, size: 26)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          club.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          club.category,
                          style: const TextStyle(color: AppTheme.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${club.city} • ${club.league}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.how_to_vote, size: 13, color: AppTheme.accent),
                      const SizedBox(width: 3),
                      Text('${club.votes} votes', style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      const Icon(Icons.people, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text('${club.followers} fans', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Associations Section ───────────────────────────────────────────────────

class _AssociationsSection extends StatelessWidget {
  final String countryCode;
  final String flag;

  const _AssociationsSection({required this.countryCode, required this.flag});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('associations')
          .where('countryCode', isEqualTo: countryCode)
          .snapshots(),
      builder: (ctx, snap) {
        final firestoreDocs = snap.data?.docs ?? [];
        final firestoreIds = firestoreDocs.map((d) => d.id).toSet();

        final hardcoded = kDefaultAssociations[countryCode] ?? [];
        final extraHardcoded = hardcoded.where((a) => !firestoreIds.contains(a['id'])).toList();

        final totalCount = firestoreDocs.length + extraHardcoded.length;
        if (totalCount == 0) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'ΕΝΩΣΕΙΣ',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ...firestoreDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? doc.id;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _AssociationTile(assocId: doc.id, name: name, flag: flag),
              );
            }),
            ...extraHardcoded.map((a) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _AssociationTile(assocId: a['id']!, name: a['name']!, flag: flag),
            )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _AssociationTile extends StatelessWidget {
  final String assocId;
  final String name;
  final String flag;

  const _AssociationTile({
    required this.assocId,
    required this.name,
    required this.flag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssociationDetailScreen(
            assocId: assocId,
            assocName: name,
            flag: flag,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppTheme.navyGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance, color: AppTheme.primaryLight, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Text(
                    'Δες κατηγορίες & ομάδες',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Association Detail Screen ──────────────────────────────────────────────

class AssociationDetailScreen extends StatelessWidget {
  final String assocId;
  final String assocName;
  final String flag;

  const AssociationDetailScreen({
    super.key,
    required this.assocId,
    required this.assocName,
    required this.flag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(assocName),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('competitions')
            .where('assocId', isEqualTo: assocId)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final firestoreDocs = snap.data?.docs ?? [];
          final firestoreIds = firestoreDocs.map((d) => d.id).toSet();

          final hardcoded = kDefaultCompetitions[assocId] ?? [];
          final extraHardcoded = hardcoded.where((c) => !firestoreIds.contains(c['id'])).toList();

          // Merge: Firestore entries + hardcoded ones not already in Firestore
          final allMen = <Map<String, String>>[];
          final allWomen = <Map<String, String>>[];

          for (final doc in firestoreDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final entry = {
              'id': doc.id,
              'name': (data['name'] as String? ?? doc.id),
              'season': (data['season'] as String? ?? '2024-2025'),
              'gender': (data['gender'] as String? ?? 'men'),
            };
            if (entry['gender'] == 'women') { allWomen.add(entry); } else { allMen.add(entry); }
          }
          for (final c in extraHardcoded) {
            if (c['gender'] == 'women') { allWomen.add(c); } else { allMen.add(c); }
          }

          if (allMen.isEmpty && allWomen.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, size: 48, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text('Δεν υπάρχουν πρωταθλήματα', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(assocName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            );
          }

          Widget buildTile(Map<String, String> c) => _CompetitionTile(
            compId: c['id']!,
            name: c['name']!,
            season: c['season'] ?? '2024-2025',
            assocName: assocName,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (allMen.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('ΑΝΔΡΙΚΟ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ),
                ...allMen.map(buildTile),
              ],
              if (allWomen.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(top: allMen.isNotEmpty ? 20 : 0, bottom: 8),
                  child: const Text('ΓΥΝΑΙΚΕΙΟ', style: TextStyle(color: Color(0xFFf472b6), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ),
                ...allWomen.map(buildTile),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CompetitionTile extends StatelessWidget {
  final String compId;
  final String name;
  final String season;
  final String assocName;

  const _CompetitionTile({
    required this.compId,
    required this.name,
    required this.season,
    required this.assocName,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompetitionClubsScreen(
            compId: compId,
            compName: name,
            assocName: assocName,
            season: season,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.navyGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events, color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    '$assocName • $season',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Competition Clubs Screen ───────────────────────────────────────────────

class CompetitionClubsScreen extends StatelessWidget {
  final String compId;
  final String compName;
  final String assocName;
  final String season;

  const CompetitionClubsScreen({
    super.key,
    required this.compId,
    required this.compName,
    required this.assocName,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(compName),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$assocName • $season',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .where('competitionId', isEqualTo: compId)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final clubs = (snap.data?.docs ?? [])
              .map((d) => ClubModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList()
            ..sort((a, b) => b.votes.compareTo(a.votes));

          if (clubs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_soccer, size: 48, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'Δεν υπάρχουν σύλλογοι',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    compName,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: clubs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _ClubListTile(club: clubs[i], rank: i + 1),
          );
        },
      ),
    );
  }
}
