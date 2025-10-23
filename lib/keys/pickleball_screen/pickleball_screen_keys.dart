class PickleballScreenKeys {
  // Screen Title
  static const String screenTitle = 'Pickleball Team Registration';

  // Form Labels
  static const String teamNameLabel = 'Team Name';
  static const String coachNameLabel = 'Team Captain Name';
  static const String coachPhoneLabel = 'Captain Phone';
  static const String coachEmailLabel = 'Captain Email';
  static const String divisionLabel = 'Division';

  // Player Form Labels
  static const String playerNameLabel = 'Player Name';
  static const String playerPhoneLabel = 'Phone Number';
  static const String playerEmailLabel = 'Email';
  static const String playerAgeLabel = 'Age';
  static const String playerSkillLevelLabel = 'Skill Level';
  static const String playerPreferredPositionLabel = 'Preferred Position';

  // Divisions (DUPR Rating)
  static const String youthDivision = 'Youth (18 or under)';
  static const String adultDivision = 'Adult 18+';
  static const String mixedDivision = 'Mixed (Any Age)';

  // DUPR Rating Options
  static const String duprRatingUnder35 = '< 3.5';
  static const String duprRatingOver4 = '> 4.0';

  // Skill Levels
  static const String beginnerSkill = 'Beginner (1.0-2.5)';
  static const String intermediateSkill = 'Intermediate (3.0-3.5)';
  static const String advancedSkill = 'Advanced (4.0-4.5)';
  static const String expertSkill = 'Expert (5.0+)';

  // Positions
  static const String anyPosition = 'Any Position';
  static const String singlesPosition = 'Singles Specialist';
  static const String doublesPosition = 'Doubles Specialist';
  static const String mixedDoublesPosition = 'Mixed Doubles';

  // Buttons
  static const String addPlayerButton = 'Add Player';
  static const String saveTeamButton = 'Save Team';
  static const String cancelButton = 'Cancel';
  static const String editPlayerButton = 'Edit';
  static const String deletePlayerButton = 'Delete';

  // Validation Messages
  static const String teamNameRequired = 'Team name is required';
  static const String coachNameRequired = 'Team captain name is required';
  static const String coachPhoneRequired = 'Captain phone is required';
  static const String coachEmailRequired = 'Captain email is required';
  static const String playerNameRequired = 'Player name is required';
  static const String playerPhoneRequired = 'Player phone is required';
  static const String playerEmailRequired = 'Player email is required';
  static const String playerAgeRequired = 'Player age is required';
  static const String skillLevelRequired = 'Skill level is required';
  static const String positionRequired = 'Preferred position is required';
  static const String addPlayerMessage = 'Please add at least one player';
  static const String invalidEmail = 'Please enter a valid email';
  static const String invalidPhone = 'Please enter a valid phone number';
  static const String invalidAge = 'Please enter a valid age (18-80)';

  // Success Messages
  static const String teamSavedSuccess = 'Team saved successfully!';
  static const String playerAddedSuccess = 'Player added successfully!';
  static const String playerUpdatedSuccess = 'Player updated successfully!';
  static const String playerDeletedSuccess = 'Player deleted successfully!';

  // Error Messages
  static const String saveError = 'Error saving team';
  static const String loadError = 'Error loading team data';

  // Tournament Info
  static const String tournamentTitle = 'Pickleball Tournament 2025';
  static const String tournamentDate = 'Sat. Nov. 8. 2025';
  static const String tournamentLocation = 'Masjid Istiqlal';
  static const String tournamentAddress =
      '123 Main Street,\nSugar Land, TX\n77498';

  // Hints
  static const String teamNameHint = 'Enter your team name';
  static const String coachNameHint = 'Enter team captain full name';
  static const String coachPhoneHint = 'Enter captain phone number';
  static const String coachEmailHint = 'Enter captain email address';
  static const String playerNameHint = 'Enter player full name';
  static const String playerPhoneHint = 'Enter player phone number';
  static const String playerEmailHint = 'Enter player email address';
  static const String playerAgeHint = 'Enter player age';
}
