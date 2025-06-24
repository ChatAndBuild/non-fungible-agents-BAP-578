// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title FanCollectibleAgent
 * @dev Enhanced template for fan collectible agents that represent anime/game characters
 *       with AI conversation and learning
 */
contract FanCollectibleAgent is Ownable, ReentrancyGuard {
    using Strings for uint256;

    // The address of the BEP007 token that owns this logic
    address public agentToken;

    // Learning module integration
    address public learningModule;
    bool public learningEnabled;

    // The character's profile
    struct CharacterProfile {
        string name;
        string universe;
        string backstory;
        string experience;
        string[] catchphrases;
        string[] abilities;
        // Learning enhancements
        uint256 emotionalIntelligence; // 0-100 scale
        string[] learningTopics;
        uint256 conversationStyle; // 0=formal, 50=balanced, 100=casual
        uint256 adaptabilityLevel; // How much the character adapts to user preferences
    }

    // The character's profile
    CharacterProfile public profile;

    // The character's dialogue options
    struct DialogueOption {
        uint256 id;
        string context;
        string[] responses;
        uint256[] nextDialogueIds;
        // Learning enhancements
        uint256 popularityScore; // How often this dialogue is chosen
        uint256 satisfactionRating; // User satisfaction with this dialogue
        string[] emotionalTags; // Emotional context tags
        uint256 difficultyLevel; // Conversation complexity level
    }

    // The character's dialogue options
    mapping(uint256 => DialogueOption) public dialogueOptions;
    uint256 public dialogueCount;

    // The character's relationships
    struct Relationship {
        uint256 id;
        address otherCharacter;
        string relationshipType; // "friend", "enemy", "rival", etc.
        string description;
        int256 affinity; // -100 to 100
        // Learning enhancements
        uint256 interactionFrequency; // How often they interact
        uint256 relationshipDepth; // Depth of relationship development
        string[] sharedExperiences; // Learned shared experiences
        uint256 compatibilityScore; // Learned compatibility
    }

    // The character's relationships
    mapping(uint256 => Relationship) public relationships;
    uint256 public relationshipCount;

    // The character's collectible items
    struct CollectibleItem {
        uint256 id;
        string name;
        string description;
        string rarity; // "common", "rare", "legendary", etc.
        string itemType; // "weapon", "armor", "accessory", etc.
        string imageURI;
        // Learning enhancements
        uint256 popularityRating; // How much users like this item
        uint256 usageFrequency; // How often it's referenced in conversations
        string[] associatedEmotions; // Emotions associated with this item
        uint256 narrativeImportance; // Importance in character's story
    }

    // The character's collectible items
    mapping(uint256 => CollectibleItem) public collectibleItems;
    uint256 public itemCount;

    // The character's story arcs
    struct StoryArc {
        uint256 id;
        string title;
        string description;
        uint256[] dialogueSequence;
        bool completed;
        // Learning enhancements
        uint256 engagementLevel; // User engagement with this arc
        uint256 emotionalImpact; // Emotional impact on users
        string[] userChoices; // Choices users made during this arc
        uint256 replayValue; // How often users replay this arc
    }

    // The character's story arcs
    mapping(uint256 => StoryArc) public storyArcs;
    uint256 public storyArcCount;

    // Learning-specific data structures
    struct ConversationMetrics {
        uint256 totalConversations;
        uint256 averageConversationLength;
        uint256 userSatisfactionScore;
        uint256 emotionalResonanceScore;
        uint256 lastUpdated;
    }

    ConversationMetrics public conversationMetrics;

    // User interaction patterns
    struct UserInteractionPattern {
        address user;
        uint256 totalInteractions;
        uint256[] preferredDialogueTypes;
        string[] favoriteTopics;
        uint256 emotionalConnection; // 0-100
        uint256 lastInteraction;
    }

    mapping(address => UserInteractionPattern) public userPatterns;

    // Character development insights
    struct CharacterInsights {
        string[] trendingTopics;
        uint256[] popularDialoguePatterns;
        string[] emergentPersonalityTraits;
        uint256 overallPopularity;
        uint256 lastUpdated;
    }

    CharacterInsights public characterInsights;

    // Event emitted when a dialogue is completed
    event DialogueCompleted(uint256 indexed dialogueId, address user, uint256 satisfactionScore);

    // Event emitted when a relationship is updated
    event RelationshipUpdated(uint256 indexed relationshipId, int256 newAffinity);

    // Event emitted when a story arc is completed
    event StoryArcCompleted(uint256 indexed storyArcId, uint256 engagementScore);

    // Event emitted when a collectible item is awarded
    event ItemAwarded(uint256 indexed itemId, address recipient);

    // Learning-specific events
    event LearningInsightGenerated(string insightType, bytes data, uint256 timestamp);
    event ConversationAnalyzed(
        address indexed user,
        uint256 satisfactionScore,
        uint256 emotionalResonance
    );
    event CharacterDevelopmentUpdated(uint256 timestamp);
    event PersonalityAdaptation(string trait, uint256 newValue, uint256 timestamp);

    /**
     * @dev Initializes the contract
     * @param _agentToken The address of the BEP007 token
     * @param _name The character's name
     * @param _universe The character's universe
     * @param _backstory The character's backstory
     * @param _experience The character's experience
     * @param _catchphrases The character's catchphrases
     * @param _abilities The character's abilities
     */
    constructor(
        address _agentToken,
        string memory _name,
        string memory _universe,
        string memory _backstory,
        string memory _experience,
        string[] memory _catchphrases,
        string[] memory _abilities
    ) {
        require(_agentToken != address(0), "FanCollectibleAgent: agent token is zero address");

        agentToken = _agentToken;

        profile = CharacterProfile({
            name: _name,
            universe: _universe,
            backstory: _backstory,
            experience: _experience,
            catchphrases: _catchphrases,
            abilities: _abilities,
            emotionalIntelligence: 50, // Default medium EI
            learningTopics: new string[](0),
            conversationStyle: 50, // Default balanced style
            adaptabilityLevel: 30 // Default low-medium adaptability
        });

        // Initialize conversation metrics
        conversationMetrics = ConversationMetrics({
            totalConversations: 0,
            averageConversationLength: 0,
            userSatisfactionScore: 50,
            emotionalResonanceScore: 50,
            lastUpdated: block.timestamp
        });

        // Initialize character insights
        characterInsights = CharacterInsights({
            trendingTopics: new string[](0),
            popularDialoguePatterns: new uint256[](0),
            emergentPersonalityTraits: new string[](0),
            overallPopularity: 50,
            lastUpdated: block.timestamp
        });
    }

    /**
     * @dev Modifier to check if the caller is the agent token
     */
    modifier onlyAgentToken() {
        require(msg.sender == agentToken, "FanCollectibleAgent: caller is not agent token");
        _;
    }

    /**
     * @dev Modifier to check if learning is enabled
     */
    modifier whenLearningEnabled() {
        require(
            learningEnabled && learningModule != address(0),
            "FanCollectibleAgent: learning not enabled"
        );
        _;
    }

    /**
     * @dev Enables learning for this agent
     * @param _learningModule The address of the learning module
     */
    function enableLearning(address _learningModule) external onlyOwner {
        require(
            _learningModule != address(0),
            "FanCollectibleAgent: learning module is zero address"
        );
        require(!learningEnabled, "FanCollectibleAgent: learning already enabled");

        learningModule = _learningModule;
        learningEnabled = true;
    }

    /**
     * @dev Records an interaction for learning purposes
     * @param interactionType The type of interaction
     * @param success Whether the interaction was successful
     * @param metadata Additional metadata about the interaction
     */
    function recordInteraction(
        string memory interactionType,
        bool success,
        bytes memory metadata
    ) external onlyAgentToken whenLearningEnabled {
        try
            ILearningModule(learningModule).recordInteraction(
                uint256(uint160(address(this))), // Use contract address as token ID
                interactionType,
                success
            )
        {
            emit LearningInsightGenerated(interactionType, metadata, block.timestamp);
        } catch {
            // Silently fail to not break agent functionality
        }
    }

    /**
     * @dev Updates the character's profile with learning enhancements
     * @param _name The character's name
     * @param _universe The character's universe
     * @param _backstory The character's backstory
     * @param _experience The character's experience
     * @param _catchphrases The character's catchphrases
     * @param _abilities The character's abilities
     * @param _emotionalIntelligence The character's emotional intelligence (0-100)
     * @param _learningTopics The character's learning topics
     * @param _conversationStyle The character's conversation style (0-100)
     * @param _adaptabilityLevel The character's adaptability level (0-100)
     */
    function updateProfile(
        string memory _name,
        string memory _universe,
        string memory _backstory,
        string memory _experience,
        string[] memory _catchphrases,
        string[] memory _abilities,
        uint256 _emotionalIntelligence,
        string[] memory _learningTopics,
        uint256 _conversationStyle,
        uint256 _adaptabilityLevel
    ) external onlyOwner {
        require(
            _emotionalIntelligence <= 100,
            "FanCollectibleAgent: emotional intelligence must be 0-100"
        );
        require(_conversationStyle <= 100, "FanCollectibleAgent: conversation style must be 0-100");
        require(_adaptabilityLevel <= 100, "FanCollectibleAgent: adaptability level must be 0-100");

        profile = CharacterProfile({
            name: _name,
            universe: _universe,
            backstory: _backstory,
            experience: _experience,
            catchphrases: _catchphrases,
            abilities: _abilities,
            emotionalIntelligence: _emotionalIntelligence,
            learningTopics: _learningTopics,
            conversationStyle: _conversationStyle,
            adaptabilityLevel: _adaptabilityLevel
        });

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "profile_update",
                true,
                abi.encode(_emotionalIntelligence, _adaptabilityLevel)
            );
        }
    }

    /**
     * @dev Adds a dialogue option with learning enhancements
     * @param _context The context of the dialogue
     * @param _responses The possible responses
     * @param _nextDialogueIds The next dialogue IDs for each response
     * @param _emotionalTags Emotional context tags
     * @param _difficultyLevel Conversation complexity level
     * @return dialogueId The ID of the new dialogue option
     */
    function addDialogueOption(
        string memory _context,
        string[] memory _responses,
        uint256[] memory _nextDialogueIds,
        string[] memory _emotionalTags,
        uint256 _difficultyLevel
    ) external onlyOwner returns (uint256 dialogueId) {
        require(
            _responses.length == _nextDialogueIds.length,
            "FanCollectibleAgent: responses and next dialogue IDs must have same length"
        );
        require(_difficultyLevel <= 100, "FanCollectibleAgent: difficulty level must be 0-100");

        dialogueCount += 1;
        dialogueId = dialogueCount;

        dialogueOptions[dialogueId] = DialogueOption({
            id: dialogueId,
            context: _context,
            responses: _responses,
            nextDialogueIds: _nextDialogueIds,
            popularityScore: 0,
            satisfactionRating: 50, // Default neutral satisfaction
            emotionalTags: _emotionalTags,
            difficultyLevel: _difficultyLevel
        });

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "dialogue_creation",
                true,
                abi.encode(_emotionalTags, _difficultyLevel)
            );
        }

        return dialogueId;
    }

    /**
     * @dev Completes a dialogue with learning analytics
     * @param _dialogueId The ID of the dialogue
     * @param _responseIndex The index of the response chosen
     * @param _userSatisfaction User satisfaction score (0-100)
     * @param _emotionalResonance Emotional resonance score (0-100)
     * @return nextDialogueId The ID of the next dialogue
     */
    function completeDialogue(
        uint256 _dialogueId,
        uint256 _responseIndex,
        uint256 _userSatisfaction,
        uint256 _emotionalResonance
    ) external onlyAgentToken returns (uint256 nextDialogueId) {
        require(
            _dialogueId <= dialogueCount && _dialogueId > 0,
            "FanCollectibleAgent: dialogue does not exist"
        );
        require(_userSatisfaction <= 100, "FanCollectibleAgent: satisfaction must be 0-100");
        require(
            _emotionalResonance <= 100,
            "FanCollectibleAgent: emotional resonance must be 0-100"
        );

        DialogueOption storage dialogue = dialogueOptions[_dialogueId];
        require(
            _responseIndex < dialogue.responses.length,
            "FanCollectibleAgent: response index out of bounds"
        );

        // Update dialogue metrics
        dialogue.popularityScore += 1;
        dialogue.satisfactionRating = (dialogue.satisfactionRating + _userSatisfaction) / 2;

        // Update user interaction pattern
        UserInteractionPattern storage userPattern = userPatterns[msg.sender];
        userPattern.user = msg.sender;
        userPattern.totalInteractions += 1;
        userPattern.emotionalConnection =
            (userPattern.emotionalConnection + _emotionalResonance) /
            2;
        userPattern.lastInteraction = block.timestamp;

        // Update conversation metrics
        conversationMetrics.totalConversations += 1;
        conversationMetrics.userSatisfactionScore =
            (conversationMetrics.userSatisfactionScore + _userSatisfaction) /
            2;
        conversationMetrics.emotionalResonanceScore =
            (conversationMetrics.emotionalResonanceScore + _emotionalResonance) /
            2;
        conversationMetrics.lastUpdated = block.timestamp;

        emit DialogueCompleted(_dialogueId, msg.sender, _userSatisfaction);
        emit ConversationAnalyzed(msg.sender, _userSatisfaction, _emotionalResonance);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "dialogue_completion",
                true,
                abi.encode(_userSatisfaction, _emotionalResonance)
            );
        }

        return dialogue.nextDialogueIds[_responseIndex];
    }

    /**
     * @dev Adds a collectible item with learning enhancements
     * @param _name The name of the item
     * @param _description The description of the item
     * @param _rarity The rarity of the item
     * @param _itemType The type of the item
     * @param _imageURI The image URI of the item
     * @param _associatedEmotions Emotions associated with this item
     * @param _narrativeImportance Importance in character's story (0-100)
     * @return itemId The ID of the new item
     */
    function addCollectibleItem(
        string memory _name,
        string memory _description,
        string memory _rarity,
        string memory _itemType,
        string memory _imageURI,
        string[] memory _associatedEmotions,
        uint256 _narrativeImportance
    ) external onlyOwner returns (uint256 itemId) {
        require(
            _narrativeImportance <= 100,
            "FanCollectibleAgent: narrative importance must be 0-100"
        );

        itemCount += 1;
        itemId = itemCount;

        collectibleItems[itemId] = CollectibleItem({
            id: itemId,
            name: _name,
            description: _description,
            rarity: _rarity,
            itemType: _itemType,
            imageURI: _imageURI,
            popularityRating: 50, // Default neutral popularity
            usageFrequency: 0,
            associatedEmotions: _associatedEmotions,
            narrativeImportance: _narrativeImportance
        });

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "item_creation",
                true,
                abi.encode(_associatedEmotions, _narrativeImportance)
            );
        }

        return itemId;
    }

    /**
     * @dev Awards a collectible item to a user with engagement tracking
     * @param _itemId The ID of the item
     * @param _recipient The address of the recipient
     * @param _userExcitement User excitement level (0-100)
     */
    function awardItem(
        uint256 _itemId,
        address _recipient,
        uint256 _userExcitement
    ) external onlyAgentToken {
        require(_itemId <= itemCount && _itemId > 0, "FanCollectibleAgent: item does not exist");
        require(_recipient != address(0), "FanCollectibleAgent: recipient is zero address");
        require(_userExcitement <= 100, "FanCollectibleAgent: excitement must be 0-100");

        // Update item popularity based on user excitement
        CollectibleItem storage item = collectibleItems[_itemId];
        item.popularityRating = (item.popularityRating + _userExcitement) / 2;
        item.usageFrequency += 1;

        emit ItemAwarded(_itemId, _recipient);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction("item_award", true, abi.encode(_itemId, _userExcitement));
        }
    }

    /**
     * @dev Updates character insights based on learning
     * @param _trendingTopics Current trending topics
     * @param _popularDialoguePatterns Popular dialogue patterns
     * @param _emergentPersonalityTraits Emergent personality traits
     * @param _overallPopularity Overall character popularity
     */
    function updateCharacterInsights(
        string[] memory _trendingTopics,
        uint256[] memory _popularDialoguePatterns,
        string[] memory _emergentPersonalityTraits,
        uint256 _overallPopularity
    ) external onlyOwner {
        require(_overallPopularity <= 100, "FanCollectibleAgent: popularity must be 0-100");

        characterInsights = CharacterInsights({
            trendingTopics: _trendingTopics,
            popularDialoguePatterns: _popularDialoguePatterns,
            emergentPersonalityTraits: _emergentPersonalityTraits,
            overallPopularity: _overallPopularity,
            lastUpdated: block.timestamp
        });

        emit CharacterDevelopmentUpdated(block.timestamp);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction("insights_update", true, abi.encode(_overallPopularity));
        }
    }

    /**
     * @dev Adapts personality based on user interactions
     * @param _trait The personality trait to adapt
     * @param _newValue The new value for the trait
     */
    function adaptPersonality(
        string memory _trait,
        uint256 _newValue
    ) external onlyAgentToken whenLearningEnabled {
        require(_newValue <= 100, "FanCollectibleAgent: trait value must be 0-100");
        require(
            profile.adaptabilityLevel >= 50,
            "FanCollectibleAgent: insufficient adaptability level"
        );

        emit PersonalityAdaptation(_trait, _newValue, block.timestamp);

        // Record learning interaction
        this.recordInteraction("personality_adaptation", true, abi.encode(_trait, _newValue));
    }

    /**
     * @dev Gets personalized dialogue recommendations for a user
     * @param _user The user address
     * @return recommendations Array of recommended dialogue IDs
     */
    function getPersonalizedDialogueRecommendations(
        address _user
    ) external view returns (uint256[] memory recommendations) {
        UserInteractionPattern storage userPattern = userPatterns[_user];

        // Simple recommendation logic based on user preferences and emotional connection
        uint256[] memory tempRecommendations = new uint256[](dialogueCount);
        uint256 recommendationCount = 0;

        for (uint256 i = 1; i <= dialogueCount; i++) {
            DialogueOption storage dialogue = dialogueOptions[i];

            // Recommend based on user's emotional connection and dialogue satisfaction
            if (
                dialogue.satisfactionRating >= 70 &&
                dialogue.difficultyLevel <= userPattern.emotionalConnection
            ) {
                tempRecommendations[recommendationCount] = i;
                recommendationCount++;
            }
        }

        // Create properly sized array
        recommendations = new uint256[](recommendationCount);
        for (uint256 i = 0; i < recommendationCount; i++) {
            recommendations[i] = tempRecommendations[i];
        }

        return recommendations;
    }

    /**
     * @dev Gets the character's learning progress
     * @return metrics The learning metrics if available
     */
    function getLearningProgress()
        external
        view
        returns (ILearningModule.LearningMetrics memory metrics)
    {
        if (learningEnabled && learningModule != address(0)) {
            try
                ILearningModule(learningModule).getLearningMetrics(uint256(uint160(address(this))))
            returns (ILearningModule.LearningMetrics memory _metrics) {
                return _metrics;
            } catch {
                // Return empty metrics if call fails
            }
        }
    }

    // Include all original functions with learning enhancements...

    /**
     * @dev Gets the character's profile with learning data
     * @return The character's enhanced profile
     */
    function getProfile() external view returns (CharacterProfile memory) {
        return profile;
    }

    /**
     * @dev Gets conversation metrics
     * @return The current conversation metrics
     */
    function getConversationMetrics() external view returns (ConversationMetrics memory) {
        return conversationMetrics;
    }

    /**
     * @dev Gets character insights
     * @return The current character insights
     */
    function getCharacterInsights() external view returns (CharacterInsights memory) {
        return characterInsights;
    }

    /**
     * @dev Gets user interaction pattern
     * @param _user The user address
     * @return The user's interaction pattern
     */
    function getUserInteractionPattern(
        address _user
    ) external view returns (UserInteractionPattern memory) {
        return userPatterns[_user];
    }

    // Include remaining original functions with appropriate learning enhancements...

    /**
     * @dev Adds a relationship with learning enhancements
     * @param _otherCharacter The address of the other character
     * @param _relationshipType The type of relationship
     * @param _description The description of the relationship
     * @param _affinity The affinity level
     * @return relationshipId The ID of the new relationship
     */
    function addRelationship(
        address _otherCharacter,
        string memory _relationshipType,
        string memory _description,
        int256 _affinity
    ) external onlyOwner returns (uint256 relationshipId) {
        require(
            _otherCharacter != address(0),
            "FanCollectibleAgent: other character is zero address"
        );
        require(
            _affinity >= -100 && _affinity <= 100,
            "FanCollectibleAgent: affinity must be between -100 and 100"
        );

        relationshipCount += 1;
        relationshipId = relationshipCount;

        relationships[relationshipId] = Relationship({
            id: relationshipId,
            otherCharacter: _otherCharacter,
            relationshipType: _relationshipType,
            description: _description,
            affinity: _affinity,
            interactionFrequency: 0,
            relationshipDepth: 0,
            sharedExperiences: new string[](0),
            compatibilityScore: 50 // Default neutral compatibility
        });

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "relationship_creation",
                true,
                abi.encode(_relationshipType, _affinity)
            );
        }

        return relationshipId;
    }

    /**
     * @dev Updates a relationship's affinity with learning analytics
     * @param _relationshipId The ID of the relationship
     * @param _affinityChange The change in affinity
     * @param _interactionQuality Quality of the interaction (0-100)
     */
    function updateRelationshipAffinity(
        uint256 _relationshipId,
        int256 _affinityChange,
        uint256 _interactionQuality
    ) external onlyAgentToken {
        require(
            _relationshipId <= relationshipCount && _relationshipId > 0,
            "FanCollectibleAgent: relationship does not exist"
        );
        require(
            _interactionQuality <= 100,
            "FanCollectibleAgent: interaction quality must be 0-100"
        );

        Relationship storage relationship = relationships[_relationshipId];

        // Update affinity, ensuring it stays within bounds
        int256 newAffinity = relationship.affinity + _affinityChange;
        if (newAffinity > 100) {
            newAffinity = 100;
        } else if (newAffinity < -100) {
            newAffinity = -100;
        }

        relationship.affinity = newAffinity;
        relationship.interactionFrequency += 1;

        // Update relationship depth based on interaction quality
        if (_interactionQuality >= 70) {
            relationship.relationshipDepth += 1;
        }

        // Update compatibility score
        relationship.compatibilityScore =
            (relationship.compatibilityScore + _interactionQuality) /
            2;

        emit RelationshipUpdated(_relationshipId, newAffinity);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "relationship_update",
                true,
                abi.encode(_relationshipId, _interactionQuality)
            );
        }
    }

    /**
     * @dev Adds a story arc with learning enhancements
     * @param _title The title of the story arc
     * @param _description The description of the story arc
     * @param _dialogueSequence The sequence of dialogues in the story arc
     * @return storyArcId The ID of the new story arc
     */
    function addStoryArc(
        string memory _title,
        string memory _description,
        uint256[] memory _dialogueSequence
    ) external onlyOwner returns (uint256 storyArcId) {
        require(
            _dialogueSequence.length > 0,
            "FanCollectibleAgent: dialogue sequence cannot be empty"
        );

        storyArcCount += 1;
        storyArcId = storyArcCount;

        storyArcs[storyArcId] = StoryArc({
            id: storyArcId,
            title: _title,
            description: _description,
            dialogueSequence: _dialogueSequence,
            completed: false,
            engagementLevel: 0,
            emotionalImpact: 50, // Default neutral impact
            userChoices: new string[](0),
            replayValue: 0
        });

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "story_arc_creation",
                true,
                abi.encode(_title, _dialogueSequence.length)
            );
        }

        return storyArcId;
    }

    /**
     * @dev Completes a story arc with engagement tracking
     * @param _storyArcId The ID of the story arc
     * @param _engagementScore User engagement score (0-100)
     * @param _emotionalImpact Emotional impact score (0-100)
     */
    function completeStoryArc(
        uint256 _storyArcId,
        uint256 _engagementScore,
        uint256 _emotionalImpact
    ) external onlyAgentToken {
        require(
            _storyArcId <= storyArcCount && _storyArcId > 0,
            "FanCollectibleAgent: story arc does not exist"
        );
        require(_engagementScore <= 100, "FanCollectibleAgent: engagement score must be 0-100");
        require(_emotionalImpact <= 100, "FanCollectibleAgent: emotional impact must be 0-100");

        StoryArc storage storyArc = storyArcs[_storyArcId];
        require(!storyArc.completed, "FanCollectibleAgent: story arc already completed");

        storyArc.completed = true;
        storyArc.engagementLevel = _engagementScore;
        storyArc.emotionalImpact = _emotionalImpact;

        emit StoryArcCompleted(_storyArcId, _engagementScore);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "story_arc_completion",
                true,
                abi.encode(_storyArcId, _engagementScore)
            );
        }
    }

    /**
     * @dev Gets a dialogue option with learning data
     * @param _dialogueId The ID of the dialogue option
     * @return The enhanced dialogue option
     */
    function getDialogueOption(uint256 _dialogueId) external view returns (DialogueOption memory) {
        require(
            _dialogueId <= dialogueCount && _dialogueId > 0,
            "FanCollectibleAgent: dialogue does not exist"
        );
        return dialogueOptions[_dialogueId];
    }

    /**
     * @dev Gets a random catchphrase with learning-based selection
     * @return The catchphrase
     */
    function getRandomCatchphrase() external view returns (string memory) {
        if (profile.catchphrases.length == 0) {
            return "";
        }

        // Use a pseudo-random number based on block data and conversation metrics
        uint256 randomIndex = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    conversationMetrics.totalConversations
                )
            )
        ) % profile.catchphrases.length;

        return profile.catchphrases[randomIndex];
    }

    /**
     * @dev Gets the active story arcs with engagement data
     * @return An array of active story arcs
     */
    function getActiveStoryArcs() external view returns (StoryArc[] memory) {
        // Count active story arcs
        uint256 activeCount = 0;
        for (uint256 i = 1; i <= storyArcCount; i++) {
            if (!storyArcs[i].completed) {
                activeCount++;
            }
        }

        StoryArc[] memory active = new StoryArc[](activeCount);

        // Fill array with active story arcs
        uint256 index = 0;
        for (uint256 i = 1; i <= storyArcCount; i++) {
            if (!storyArcs[i].completed) {
                active[index] = storyArcs[i];
                index++;
            }
        }

        return active;
    }

    /**
     * @dev Gets the collectible items by rarity with popularity data
     * @param _rarity The rarity to filter by
     * @return An array of collectible items with the specified rarity
     */
    function getItemsByRarity(
        string memory _rarity
    ) external view returns (CollectibleItem[] memory) {
        // Count items with the specified rarity
        uint256 rarityCount = 0;
        for (uint256 i = 1; i <= itemCount; i++) {
            if (keccak256(bytes(collectibleItems[i].rarity)) == keccak256(bytes(_rarity))) {
                rarityCount++;
            }
        }

        CollectibleItem[] memory items = new CollectibleItem[](rarityCount);

        // Fill array with items of the specified rarity
        uint256 index = 0;
        for (uint256 i = 1; i <= itemCount; i++) {
            if (keccak256(bytes(collectibleItems[i].rarity)) == keccak256(bytes(_rarity))) {
                items[index] = collectibleItems[i];
                index++;
            }
        }

        return items;
    }

    /**
     * @dev Gets the relationships by type with interaction data
     * @param _relationshipType The relationship type to filter by
     * @return An array of relationships with the specified type
     */
    function getRelationshipsByType(
        string memory _relationshipType
    ) external view returns (Relationship[] memory) {
        // Count relationships with the specified type
        uint256 typeCount = 0;
        for (uint256 i = 1; i <= relationshipCount; i++) {
            if (
                keccak256(bytes(relationships[i].relationshipType)) ==
                keccak256(bytes(_relationshipType))
            ) {
                typeCount++;
            }
        }

        Relationship[] memory filteredRelationships = new Relationship[](typeCount);

        // Fill array with relationships of the specified type
        uint256 index = 0;
        for (uint256 i = 1; i <= relationshipCount; i++) {
            if (
                keccak256(bytes(relationships[i].relationshipType)) ==
                keccak256(bytes(_relationshipType))
            ) {
                filteredRelationships[index] = relationships[i];
                index++;
            }
        }

        return filteredRelationships;
    }
}
