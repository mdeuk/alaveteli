# -*- encoding : utf-8 -*-
class WorldFOIWebsites
  EU_COUNTRIES = { 'BE' => 'Belgium',
                   'BG' => 'Bulgaria',
                   'CZ' => 'Czech Republic',
                   'DK' => 'Denmark',
                   'DE' => 'Germany',
                   'EE' => 'Estonia',
                   'IE' => 'Ireland',
                   'GR' => 'Greece',
                   'ES' => 'Spain',
                   'FR' => 'France',
                   'HR' => 'Croatia',
                   'IT' => 'Italy',
                   'CY' => 'Cyprus',
                   'LV' => 'Latvia',
                   'LT' => 'Lithuania',
                   'LU' => 'Luxembourg',
                   'HU' => 'Hungary',
                   'MT' => 'Malta',
                   'NL' => 'Netherlands',
                   'AT' => 'Austria',
                   'PL' => 'Poland',
                   'PT' => 'Portugal',
                   'RO' => 'Romania',
                   'SI' => 'Slovenia',
                   'SK' => 'Slovakia',
                   'FI' => 'Finland',
                   'SE' => 'Sweden',
                   'GB' => 'United Kingdom' }.freeze

  def self.world_foi_websites
    world_foi_websites = [
      { :name => "WhatDoTheyKnow",
        :country_name => "United Kingdom",
        :country_iso_code => "GB",
        :url => "https://www.whatdotheyknow.com" },
      { :name => "Ask The EU",
        :country_name => "European Union",
        :country_iso_code => "",
        :url => "http://asktheeu.org" },
      { :name => "MuckRock.com",
        :country_name => "United States of America",
        :country_iso_code => "US",
        :url => "http://www.muckrock.com" },
      { :name => "FYI",
        :country_name => "New Zealand",
        :country_iso_code => "NZ",
        :url => "http://fyi.org.nz" },
      { :name => "Frag den Staat",
        :country_name => "Deutschland",
        :country_iso_code => "DE",
        :url => "http://fragdenstaat.de" },
      { :name => "Queremos Saber",
        :country_name => "Brasil",
        :country_iso_code => "BR",
        :url => "http://queremossaber.org.br" },
      { :name => "Ki Mit Tud",
        :country_name => "Magyarország",
        :country_iso_code => "HU",
        :url => "http://kimittud.atlatszo.hu/" },
      { :name => "PravoDaSznam",
        :country_name => "Bosna i Hercegovina",
        :country_iso_code => "BA",
        :url => "http://www.pravodaznam.ba/" },
      { :name => "Right To Know",
        :country_name => "Australia",
        :country_iso_code => "AU",
        :url => "http://www.righttoknow.org.au" },
      { :name => "Informace pro Vsechny",
        :country_name => "České Republiky",
        :country_iso_code => "CZ",
        :url => "http://www.infoprovsechny.cz" },
      { :name => "¿Qué Sabés?",
        :country_name => "Uruguay",
        :country_iso_code => "UY",
        :url => "http://www.quesabes.org/" },
      { :name => "Nu Vă Supărați",
        :country_name => "România",
        :country_iso_code => "RO",
        :url => "http://nuvasuparati.info/" },
      { :name => "Доступ до правди",
        :country_name => "Україна",
        :country_iso_code => "UA",
        :url => "https://dostup.pravda.com.ua/" },
      { :name => "Ask Data",
        :country_name => "מְדִינַת יִשְׂרָאֵל",
        :country_iso_code => "IL",
        :url => "http://askdata.org.il/" },
      { :name => "Слободен пристап",
        :country_name => "Република Македонија",
        :country_iso_code => "MK",
        :url => "http://www.slobodenpristap.mk/" },
      { :name => "Imamo pravo znati",
        :country_name => "Republika Hrvatska",
        :country_iso_code => "HR",
        :url => "http://imamopravoznati.org/" },
      { :name => "РосОтвет",
        :country_name => "Россия",
        :country_iso_code => "RU",
        :url => "http://rosotvet.ru/" },
      { :name => 'Right2Know.my',
        :country_name => 'Malaysia',
        :country_iso_code => 'MY',
        :url => "http://foi.sinarproject.org/" },
      { :name => 'Sobanukirwa',
        :country_name => 'Rwanda',
        :country_iso_code => 'RW',
        :url => "https://sobanukirwa.rw/" },
      { :name => 'Chiedi',
        :country_name => 'Italia',
        :country_iso_code => 'IT',
        :url => "https://chiedi.dirittodisapere.it/" },
      { :name => 'AccessInfo.hk',
        :country_name => '香港',
        :country_iso_code => 'HK',
        :url => "https://accessinfo.hk/" },
      { :name => 'Ask Your Government Uganda',
        :country_name => 'Uganda',
        :country_iso_code => 'UG',
        :url => "http://askyourgov.ug/" },
      { :name => 'Mimes Brønn',
        :country_name => 'Norge',
        :country_iso_code => 'NO',
        :url => "https://www.mimesbronn.no/" },
      { :name => 'QueremoSaber',
        :country_name => 'Paraguay',
        :country_iso_code => 'PY',
        :url => "https://www.queremosaber.org.py/" },
      { :name => 'Derecho a Preguntar',
        :country_name => 'Nicaragua',
        :country_iso_code => 'NI',
        :url => "https://derechoapreguntar.org/" },
      { :name => 'InfoLib',
        :country_name => 'Liberia',
        :country_iso_code => 'LR',
        :url => "http://infolib.org.lr/" },
      { :name => 'MaDada',
        :country_name => 'France',
        :country_iso_code => 'FR',
        :url => "https://madada.fr/" },
      { :name => 'Handlingar',
        :country_name => 'Sweden',
        :country_iso_code => 'SE',
        :url => "https://handlingar.se/" },
      { :name => 'VreauInfo',
        :country_name => 'Moldova',
        :country_iso_code => 'MD',
        :url => "https://www.vreauinfo.md/" },
      { :name => 'Derecho al Dato',
        :country_name => 'Argentina',
        :country_iso_code => 'AR',
        :url => 'https://derechoaldato.com.ar/' },
    ]
    return world_foi_websites
  end

  def self.by_code(code)
    result = self.world_foi_websites.find { |x| x[:country_iso_code].downcase == code.downcase }
    return result
  end

  def self.can_ask_the_eu?(code)
    country_in_eu?(code) && !is_ask_the_eu?
  end

  def self.country_in_eu?(code)
    EU_COUNTRIES.key?(code.to_s.upcase)
  end

  def self.is_ask_the_eu?
    AlaveteliConfiguration.domain == 'www.asktheeu.org'
  end

end
