/**
 * VoltEZ — EV User Survey (Google Apps Script)
 *
 * HOW TO USE:
 * 1. Open Google Sheets → Extensions → Apps Script
 * 2. Paste this entire script into the editor
 * 3. Click ▶ Run → select "createSurvey"
 * 4. Authorize when prompted (one-time)
 * 5. A new Google Form link will appear in the console
 */

function createSurvey() {
  const form = FormApp.create('VoltEZ — EV User Experience Survey');
  form.setDescription(
    'Help us build the smartest EV charging companion. ' +
    'This 3-minute survey covers your vehicle, charging habits, costs, and what features matter most to you. ' +
    'Your responses are anonymous and will directly shape VoltEZ.'
  );
  form.setAllowResponseEdits(false);
  form.setCollectEmail(false);
  form.setConfirmationMessage('Thank you! Your feedback will help us build a better charging experience. ⚡');
  form.setProgressBar(true);

  // ═══════════════════════════════════════════════════════════════
  // SECTION 1 — About You & Your Vehicle
  // ═══════════════════════════════════════════════════════════════
  form.addSectionHeaderItem()
    .setTitle('🚗  About You & Your Vehicle');

  form.addMultipleChoiceItem()
    .setTitle('Do you currently own or lease an electric vehicle?')
    .setChoiceValues([
      'Yes — Battery Electric Vehicle (BEV)',
      'Yes — Plug-in Hybrid (PHEV)',
      'No — I\'m planning to buy one within 6 months',
      'No — I\'m considering one but not sure yet',
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('What is your EV brand / model?')
    .setChoiceValues([
      'Tata Nexon EV / Tiago EV / Tigor EV',
      'MG ZS EV / MG Comet',
      'Hyundai Ioniq 5 / Kona Electric',
      'Mahindra XUV400 / XEV 9e',
      'BYD Atto 3 / Seal',
      'Mercedes / BMW / Audi (luxury EV)',
      'Other Indian brand',
      'Other import',
      'I don\'t own an EV yet',
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('What is your EV\'s battery capacity?')
    .setChoiceValues([
      'Under 25 kWh (city commuter)',
      '25–40 kWh (compact SUV / hatch)',
      '40–60 kWh (mid-range SUV)',
      '60–80 kWh (premium / long-range)',
      '80+ kWh (luxury / performance)',
      'I\'m not sure',
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('What connector type does your EV use?')
    .setChoiceValues([
      'CCS2 (DC fast charging)',
      'Type 2 (AC slow / medium)',
      'CHAdeMO',
      'Both CCS2 and Type 2',
      'I\'m not sure',
    ])
    .setRequired(true);

  // ═══════════════════════════════════════════════════════════════
  // SECTION 2 — Charging Habits
  // ═══════════════════════════════════════════════════════════════
  form.addSectionHeaderItem()
    .setTitle('⚡  Your Charging Routine');

  form.addMultipleChoiceItem()
    .setTitle('How do you primarily charge your EV?')
    .setChoiceValues([
      'Home charging (dedicated wall box / portable charger)',
      'Workplace charging',
      'Public DC fast chargers',
      'Public AC chargers (malls, cafes, etc.)',
      'A mix of home + public',
      'I rely entirely on public chargers',
    ])
    .setRequired(true);

  form.addCheckboxesItem()
    .setTitle('Where do you usually find public chargers? (Select all that apply)')
    .setChoiceValues([
      'Google Maps search',
      'Charger brand apps (Tata Power, Ather, Zeon, etc.)',
      'Word of mouth / friends',
      'VoltEZ',
      'Other apps or websites',
      'I struggle to find chargers',
    ]);

  form.addMultipleChoiceItem()
    .setTitle('On a typical day, how much range do you drive?')
    .setChoiceValues([
      'Under 30 km (short city commute)',
      '30–80 km (daily commute + errands)',
      '80–150 km (intercity / long commute)',
      '150–300 km (road trips / fleet use)',
      '300+ km (heavy use)',
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('How often do you charge per week?')
    .setChoiceValues([
      'Once a week or less',
      '2–3 times a week',
      '4–5 times a week (almost daily)',
      'Multiple times a day',
    ])
    .setRequired(true);

  // ═══════════════════════════════════════════════════════════════
  // SECTION 3 — Cost & Time
  // ═══════════════════════════════════════════════════════════════
  form.addSectionHeaderItem()
    .setTitle('💰  Cost & Time');

  form.addMultipleChoiceItem()
    .setTitle('How much do you spend on EV charging per month (approx.)?')
    .setChoiceValues([
      'Under ₹1,000',
      '₹1,000 – ₹2,500',
      '₹2,500 – ₹5,000',
      '₹5,000 – ₹10,000',
      'Over ₹10,000',
      'I\'m not sure / I haven\'t tracked',
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('What is the average price you pay per kWh at public chargers?')
    .setChoiceValues([
      'Under ₹8/kWh',
      '₹8 – ₹12/kWh',
      '₹12 – ₹16/kWh',
      '₹16 – ₹22/kWh',
      'Over ₹22/kWh',
      'I\'m not sure',
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('How long does a typical public charging session take?')
    .setChoiceValues([
      'Under 30 minutes (DC fast)',
      '30–60 minutes',
      '1–2 hours',
      '2–4 hours (AC charging)',
      'I only charge at home (no wait)',
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('How do you perceive the cost of EV charging vs petrol/diesel?')
    .setChoiceValues([
      'Much cheaper — I save a lot',
      'Somewhat cheaper — noticeable savings',
      'About the same — no big difference',
      'Sometimes more expensive (peak / highway rates)',
      'I\'m new to EVs — not sure yet',
    ]);

  form.addLinearScaleItem()
    .setTitle('How satisfied are you with the overall cost of charging your EV?')
    .setBounds(1, 5)
    .setLabels('Very dissatisfied', 'Very satisfied')
    .setRequired(true);

  // ═══════════════════════════════════════════════════════════════
  // SECTION 4 — Pain Points & Frustrations
  // ═══════════════════════════════════════════════════════════════
  form.addSectionHeaderItem()
    .setTitle('😤  Pain Points & Frustrations');

  form.addCheckboxesItem()
    .setTitle('What are your biggest frustrations with EV charging? (Select top 3)')
    .setMaxSelections(3)
    .setChoiceValues([
      'Can\'t find available chargers nearby',
      'Chargers are broken / unreliable',
      'Long wait times at busy stations',
      'Confusing pricing across different networks',
      'Need separate apps for each charger brand',
      'No real-time slot availability info',
      'Range anxiety on long trips',
      'Poor charger locations (unsafe / no amenities)',
      'Payment is clunky (QR codes, multiple wallets)',
      'No route planning with charge stops',
      'Other',
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('Have you ever arrived at a charger and found it occupied or broken?')
    .setChoiceValues([
      'Yes — very often (weekly)',
      'Yes — occasionally (monthly)',
      'Rarely (a few times a year)',
      'Never',
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('How do you currently plan long trips (150+ km) in your EV?')
    .setChoiceValues([
      'I don\'t — I avoid long trips',
      'Google Maps + hoping for chargers along the way',
      'Dedicated charger apps (Tata Power, etc.)',
      'Manually researching chargers on the route',
      'I use VoltEZ route planner',
      'I have range anxiety and prefer not to',
    ]);

  // ═══════════════════════════════════════════════════════════════
  // SECTION 5 — VoltEZ Feature Interest
  // ═══════════════════════════════════════════════════════════════
  form.addSectionHeaderItem()
    .setTitle('✨  VoltEZ Features');

  form.addCheckboxesItem()
    .setTitle('Which VoltEZ features would you use most? (Select all that interest you)')
    .setChoiceValues([
      '🗺️ Smart Route Planner — AI finds the best charging stops on your trip',
      '📍 Real-time Charger Map — see live availability, prices, and wait times',
      '⏱️ Slot Booking — reserve a charger slot in advance, no wait',
      '💰 Price Comparison — find the cheapest charger nearby in real-time',
      '🔋 Battery Health Tracker — monitor your EV battery over time',
      '📊 Monthly Savings Report — see how much you saved vs petrol',
      '🤖 AI Trip Assistant — get personalised charging recommendations',
      '⭐ Charger Reviews — community ratings and feedback',
      '🏢 Business Dashboard — manage your charger fleet (for businesses)',
      '🔔 Smart Notifications — alerts when price drops or slot opens',
    ])
    .setRequired(true);

  form.addLinearScaleItem()
    .setTitle('How likely are you to switch to VoltEZ if it solved your top 3 frustrations?')
    .setBounds(1, 10)
    .setLabels('Not likely at all', 'Extremely likely')
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('Would you pay for a premium VoltEZ subscription if it included exclusive features?')
    .setChoiceValues([
      'Yes — if it saves me time and money (₹99–199/month is fine)',
      'Maybe — depends on what features are included',
      'No — I prefer free apps only',
      'I\'d try a free trial first, then decide',
    ])
    .setRequired(true);

  // ═══════════════════════════════════════════════════════════════
  // SECTION 6 — App & Tech Habits
  // ═══════════════════════════════════════════════════════════════
  form.addSectionHeaderItem()
    .setTitle('📱  Your App Habits');

  form.addCheckboxesItem()
    .setTitle('Which EV-related apps do you currently use? (Select all)')
    .setChoiceValues([
      'Tata Power EZ Charge',
      'Ather Grid',
      'Zeo (formerly GOSEN)',
      'PlugShare',
      'Google Maps (for charger search)',
      'None — I don\'t use any EV app',
      'Other',
    ]);

  form.addMultipleChoiceItem()
    .setTitle('What phone do you use?')
    .setChoiceValues([
      'Android (Samsung / OnePlus / Xiaomi / other)',
      'iPhone (iOS)',
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('How often do you use EV charging apps in a week?')
    .setChoiceValues([
      'Daily',
      'A few times a week',
      'Once a week',
      'Rarely / only when traveling',
      'Never',
    ]);

  // ═══════════════════════════════════════════════════════════════
  // SECTION 7 — Final Thoughts
  // ═══════════════════════════════════════════════════════════════
  form.addSectionHeaderItem()
    .setTitle('💬  Final Thoughts');

  form.addParagraphTextItem()
    .setTitle('If you could change ONE thing about EV charging in India, what would it be?')
    .setRequired(false);

  form.addParagraphTextItem()
    .setTitle('Any other features or suggestions for VoltEZ?')
    .setRequired(false);

  form.addMultipleChoiceItem()
    .setTitle('Would you like to be part of VoltEZ\'s beta testing program?')
    .setChoiceValues([
      'Yes — I\'d love early access (we\'ll reach out)',
      'Maybe — tell me more first',
      'No thanks',
    ]);

  form.addEmailItem()
    .setTitle('Optional: Your email (only if you want beta access or updates)')
    .setRequired(false);

  // ═══════════════════════════════════════════════════════════════
  // DONE
  // ═══════════════════════════════════════════════════════════════
  Logger.log('');
  Logger.log('══════════════════════════════════════════════');
  Logger.log('  ✅  VoltEZ Survey created successfully!');
  Logger.log('══════════════════════════════════════════════');
  Logger.log('');
  Logger.log('Form URL (edit):   ' + form.getEditUrl());
  Logger.log('Form URL (public): ' + form.getPublishedUrl());
  Logger.log('');
  Logger.log('Total questions: ' + form.getItems().length);
  Logger.log('Sections: 7');

  return form;
}
