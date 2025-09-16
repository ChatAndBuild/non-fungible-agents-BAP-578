// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title GameAgent
 * @dev Template for gaming-focused Non-Fungible Agents (NFAs) on BAP-578
 *
 * This template enables agents to function as:
 * - NPCs (Non-Player Characters) with dialogue, behavior patterns, and interactions
 * - Item management systems for inventory, trading, and crafting
 * - Quest providers and reward distributors
 * - Gaming ecosystem participants with learning capabilities
 *
 * Features:
 * - NPC behavior and dialogue management
 * - Item inventory and trading system
 * - Quest creation and tracking
 * - Player interaction tracking
 * - Learning module integration for adaptive behavior
 * - BAP-578 token integration for ownership and governance
 */
contract GameAgent is Ownable, ReentrancyGuard, Pausable {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ============ STATE VARIABLES ============

    /// @dev Reference to the BAP-578 token contract
    address public agentToken;

    /// @dev Learning module integration
    address public learningModule;
    bool public learningEnabled;

    /// @dev Agent profile and characteristics
    struct AgentProfile {
        string name;
        string description;
        string gameWorld;
        string characterClass;
        uint8 level;
        uint256 experience;
        uint256 reputation;
        bool isActive;
    }

    /// @dev Item structure for inventory management
    struct Item {
        uint256 itemId;
        string name;
        string description;
        uint8 itemType; // 0: Weapon, 1: Armor, 2: Consumable, 3: Quest, 4: Currency
        uint256 rarity; // 1-5 (Common to Legendary)
        uint256 value;
        uint256 quantity;
        bool isTradeable;
        bool isCraftable;
        address owner;
    }

    /// @dev NPC dialogue and interaction data
    struct NPCDialogue {
        uint256 dialogueId;
        string greeting;
        string[] responses;
        uint256[] responseConditions; // Conditions for each response
        uint8 mood; // 0: Neutral, 1: Friendly, 2: Hostile, 3: Suspicious
        uint256 lastInteraction;
        uint256 interactionCount;
    }

    /// @dev Quest structure for quest management
    struct Quest {
        uint256 questId;
        string title;
        string description;
        uint8 questType; // 0: Kill, 1: Collect, 2: Escort, 3: Delivery, 4: Craft
        uint256[] requiredItems;
        uint256[] requiredQuantities;
        uint256[] rewardItems;
        uint256[] rewardQuantities;
        uint256 experienceReward;
        uint256 reputationReward;
        uint256 deadline;
        bool isActive;
        bool isCompleted;
        address questGiver;
        address questTaker;
    }

    /// @dev Player interaction tracking
    struct PlayerInteraction {
        address player;
        uint256 interactionCount;
        uint256 lastInteraction;
        uint256 reputationWithAgent;
        bool hasActiveQuest;
        uint256[] completedQuests;
        uint256[] activeQuests;
    }

    /// @dev Trading and economy data
    struct TradeOffer {
        uint256 offerId;
        address trader;
        uint256[] offerItems;
        uint256[] offerQuantities;
        uint256[] requestItems;
        uint256[] requestQuantities;
        uint256 deadline;
        bool isActive;
        bool isCompleted;
    }

    /// @dev Agent profile
    AgentProfile public profile;

    /// @dev Inventory management
    mapping(uint256 => Item) public items;
    mapping(uint256 => uint256) public itemQuantities; // itemId => quantity
    EnumerableSet.UintSet private itemIds;

    /// @dev NPC dialogue system
    NPCDialogue public dialogue;

    /// @dev Quest management
    mapping(uint256 => Quest) public quests;
    Counters.Counter private _questIdCounter;
    EnumerableSet.UintSet private activeQuests;
    EnumerableSet.UintSet private completedQuests;

    /// @dev Player interactions
    mapping(address => PlayerInteraction) public playerInteractions;
    EnumerableSet.AddressSet private interactedPlayers;

    /// @dev Trading system
    mapping(uint256 => TradeOffer) public tradeOffers;
    Counters.Counter private _tradeOfferIdCounter;
    EnumerableSet.UintSet private activeTradeOffers;

    /// @dev Agent statistics
    uint256 public totalInteractions;
    uint256 public totalQuestsGiven;
    uint256 public totalQuestsCompleted;
    uint256 public totalItemsTraded;
    uint256 public totalValueTraded;

    /// @dev Agent configuration
    uint256 public maxInventorySize;
    uint256 public maxActiveQuests;
    uint256 public interactionCooldown;
    bool public acceptsTrades;
    bool public acceptsQuests;

    // ============ EVENTS ============

    event AgentInitialized(
        address indexed agentToken,
        string name,
        string gameWorld,
        string characterClass
    );

    event ItemAdded(
        uint256 indexed itemId,
        string name,
        uint8 itemType,
        uint256 rarity,
        uint256 quantity
    );

    event ItemRemoved(uint256 indexed itemId, uint256 quantity);

    event ItemTraded(
        uint256 indexed itemId,
        address indexed from,
        address indexed to,
        uint256 quantity
    );

    event QuestCreated(
        uint256 indexed questId,
        string title,
        uint8 questType,
        address indexed questGiver
    );

    event QuestAccepted(uint256 indexed questId, address indexed questTaker);

    event QuestCompleted(
        uint256 indexed questId,
        address indexed questTaker,
        uint256 experienceReward,
        uint256 reputationReward
    );

    event PlayerInteracted(address indexed player, uint8 mood, uint256 interactionCount);

    event TradeOfferCreated(
        uint256 indexed offerId,
        address indexed trader,
        uint256[] offerItems,
        uint256[] requestItems
    );

    event TradeOfferAccepted(
        uint256 indexed offerId,
        address indexed acceptor,
        address indexed trader
    );

    event DialogueUpdated(uint256 indexed dialogueId, string greeting, uint8 mood);

    event LearningUpdate(string updateType, bytes32 dataHash, uint256 timestamp);

    // ============ MODIFIERS ============

    modifier onlyTokenOwner() {
        // This would need to be implemented based on BAP-578 token ownership
        require(msg.sender == owner(), "GameAgent: caller is not the owner");
        _;
    }

    modifier validItem(uint256 itemId) {
        require(items[itemId].itemId != 0, "GameAgent: item does not exist");
        _;
    }

    modifier validQuest(uint256 questId) {
        require(quests[questId].questId != 0, "GameAgent: quest does not exist");
        _;
    }

    modifier questNotCompleted(uint256 questId) {
        require(!quests[questId].isCompleted, "GameAgent: quest already completed");
        _;
    }

    modifier withinInventoryLimit(uint256 additionalItems) {
        require(
            itemIds.length() + additionalItems <= maxInventorySize,
            "GameAgent: inventory limit exceeded"
        );
        _;
    }

    // ============ INITIALIZATION ============

    /**
     * @dev Initializes the Game Agent contract
     * @param agentTokenAddress The address of the BAP-578 token
     * @param name The agent's name
     * @param gameWorld The game world the agent belongs to
     * @param characterClass The agent's character class
     * @param maxInventory Maximum inventory size
     */
    constructor(
        address agentTokenAddress,
        string memory name,
        string memory gameWorld,
        string memory characterClass,
        uint256 maxInventory
    ) {
        require(agentTokenAddress != address(0), "GameAgent: invalid agent token address");
        require(bytes(name).length > 0, "GameAgent: name cannot be empty");
        require(bytes(gameWorld).length > 0, "GameAgent: game world cannot be empty");
        require(maxInventory > 0, "GameAgent: max inventory must be greater than 0");

        agentToken = agentTokenAddress;
        maxInventorySize = maxInventory;
        maxActiveQuests = 10;
        interactionCooldown = 300; // 5 minutes
        acceptsTrades = true;
        acceptsQuests = true;

        // Initialize agent profile
        profile = AgentProfile({
            name: name,
            description: "",
            gameWorld: gameWorld,
            characterClass: characterClass,
            level: 1,
            experience: 0,
            reputation: 100,
            isActive: true
        });

        // Initialize dialogue
        dialogue = NPCDialogue({
            dialogueId: 1,
            greeting: "Greetings, traveler!",
            responses: new string[](0),
            responseConditions: new uint256[](0),
            mood: 0,
            lastInteraction: 0,
            interactionCount: 0
        });

        emit AgentInitialized(agentTokenAddress, name, gameWorld, characterClass);
    }

    // ============ CORE FUNCTIONS ============

    /**
     * @dev Updates the agent's profile
     * @param newName New agent name
     * @param newDescription New agent description
     * @param newLevel New agent level
     */
    function updateProfile(
        string memory newName,
        string memory newDescription,
        uint8 newLevel
    ) external onlyOwner {
        require(bytes(newName).length > 0, "GameAgent: name cannot be empty");
        require(newLevel > 0, "GameAgent: level must be greater than 0");

        profile.name = newName;
        profile.description = newDescription;
        profile.level = newLevel;
    }

    /**
     * @dev Adds an item to the agent's inventory
     * @param name Item name
     * @param description Item description
     * @param itemType Item type (0-4)
     * @param rarity Item rarity (1-5)
     * @param value Item value
     * @param quantity Item quantity
     * @param isTradeable Whether item can be traded
     * @param isCraftable Whether item can be crafted
     */
    function addItem(
        string memory name,
        string memory description,
        uint8 itemType,
        uint256 rarity,
        uint256 value,
        uint256 quantity,
        bool isTradeable,
        bool isCraftable
    ) external onlyOwner withinInventoryLimit(1) {
        require(bytes(name).length > 0, "GameAgent: item name cannot be empty");
        require(itemType <= 4, "GameAgent: invalid item type");
        require(rarity >= 1 && rarity <= 5, "GameAgent: invalid rarity");
        require(quantity > 0, "GameAgent: quantity must be greater than 0");

        uint256 itemId = uint256(keccak256(abi.encodePacked(name, block.timestamp, msg.sender)));

        items[itemId] = Item({
            itemId: itemId,
            name: name,
            description: description,
            itemType: itemType,
            rarity: rarity,
            value: value,
            quantity: quantity,
            isTradeable: isTradeable,
            isCraftable: isCraftable,
            owner: address(this)
        });

        itemQuantities[itemId] = quantity;
        itemIds.add(itemId);

        emit ItemAdded(itemId, name, itemType, rarity, quantity);
    }

    /**
     * @dev Removes an item from the agent's inventory
     * @param itemId Item ID to remove
     * @param quantity Quantity to remove
     */
    function removeItem(uint256 itemId, uint256 quantity) external onlyOwner validItem(itemId) {
        require(quantity > 0, "GameAgent: quantity must be greater than 0");
        require(itemQuantities[itemId] >= quantity, "GameAgent: insufficient quantity");

        itemQuantities[itemId] -= quantity;
        items[itemId].quantity = itemQuantities[itemId];

        if (itemQuantities[itemId] == 0) {
            itemIds.remove(itemId);
            delete items[itemId];
            delete itemQuantities[itemId];
        }

        emit ItemRemoved(itemId, quantity);
    }

    /**
     * @dev Creates a new quest
     * @param title Quest title
     * @param description Quest description
     * @param questType Quest type (0-4)
     * @param requiredItems Array of required item IDs
     * @param requiredQuantities Array of required quantities
     * @param rewardItems Array of reward item IDs
     * @param rewardQuantities Array of reward quantities
     * @param experienceReward Experience reward
     * @param reputationReward Reputation reward
     * @param deadline Quest deadline (0 for no deadline)
     */
    function createQuest(
        string memory title,
        string memory description,
        uint8 questType,
        uint256[] memory requiredItems,
        uint256[] memory requiredQuantities,
        uint256[] memory rewardItems,
        uint256[] memory rewardQuantities,
        uint256 experienceReward,
        uint256 reputationReward,
        uint256 deadline
    ) external onlyOwner {
        require(bytes(title).length > 0, "GameAgent: quest title cannot be empty");
        require(questType <= 4, "GameAgent: invalid quest type");
        require(
            requiredItems.length == requiredQuantities.length,
            "GameAgent: arrays length mismatch"
        );
        require(rewardItems.length == rewardQuantities.length, "GameAgent: arrays length mismatch");
        require(activeQuests.length() < maxActiveQuests, "GameAgent: max active quests reached");

        _questIdCounter.increment();
        uint256 questId = _questIdCounter.current();

        quests[questId] = Quest({
            questId: questId,
            title: title,
            description: description,
            questType: questType,
            requiredItems: requiredItems,
            requiredQuantities: requiredQuantities,
            rewardItems: rewardItems,
            rewardQuantities: rewardQuantities,
            experienceReward: experienceReward,
            reputationReward: reputationReward,
            deadline: deadline,
            isActive: true,
            isCompleted: false,
            questGiver: address(this),
            questTaker: address(0)
        });

        activeQuests.add(questId);
        totalQuestsGiven++;

        emit QuestCreated(questId, title, questType, address(this));
    }

    /**
     * @dev Accepts a quest
     * @param questId Quest ID to accept
     */
    function acceptQuest(uint256 questId) external validQuest(questId) questNotCompleted(questId) {
        require(quests[questId].isActive, "GameAgent: quest is not active");
        require(quests[questId].questTaker == address(0), "GameAgent: quest already taken");
        require(
            block.timestamp < quests[questId].deadline || quests[questId].deadline == 0,
            "GameAgent: quest deadline passed"
        );

        quests[questId].questTaker = msg.sender;

        // Update player interaction
        if (!interactedPlayers.contains(msg.sender)) {
            playerInteractions[msg.sender] = PlayerInteraction({
                player: msg.sender,
                interactionCount: 0,
                lastInteraction: block.timestamp,
                reputationWithAgent: 100,
                hasActiveQuest: true,
                completedQuests: new uint256[](0),
                activeQuests: new uint256[](0)
            });
            interactedPlayers.add(msg.sender);
        }

        playerInteractions[msg.sender].activeQuests.push(questId);
        playerInteractions[msg.sender].hasActiveQuest = true;

        emit QuestAccepted(questId, msg.sender);
    }

    /**
     * @dev Completes a quest (only quest taker can complete)
     * @param questId Quest ID to complete
     * @param submittedItems Array of submitted item IDs
     * @param submittedQuantities Array of submitted quantities
     */
    function completeQuest(
        uint256 questId,
        uint256[] memory submittedItems,
        uint256[] memory submittedQuantities
    ) external validQuest(questId) questNotCompleted(questId) {
        require(quests[questId].questTaker == msg.sender, "GameAgent: not quest taker");
        require(quests[questId].isActive, "GameAgent: quest is not active");
        require(
            submittedItems.length == submittedQuantities.length,
            "GameAgent: arrays length mismatch"
        );

        Quest storage quest = quests[questId];

        // Verify quest requirements are met
        for (uint256 i = 0; i < quest.requiredItems.length; i++) {
            bool requirementMet = false;
            for (uint256 j = 0; j < submittedItems.length; j++) {
                if (
                    quest.requiredItems[i] == submittedItems[j] &&
                    quest.requiredQuantities[i] <= submittedQuantities[j]
                ) {
                    requirementMet = true;
                    break;
                }
            }
            require(requirementMet, "GameAgent: quest requirements not met");
        }

        // Mark quest as completed
        quest.isCompleted = true;
        quest.isActive = false;
        activeQuests.remove(questId);
        completedQuests.add(questId);

        // Update player interaction
        playerInteractions[msg.sender].completedQuests.push(questId);
        playerInteractions[msg.sender].reputationWithAgent += quest.reputationReward;
        playerInteractions[msg.sender].hasActiveQuest = false;

        // Remove completed quest from active quests
        uint256[] storage activePlayerQuests = playerInteractions[msg.sender].activeQuests;
        for (uint256 i = 0; i < activePlayerQuests.length; i++) {
            if (activePlayerQuests[i] == questId) {
                activePlayerQuests[i] = activePlayerQuests[activePlayerQuests.length - 1];
                activePlayerQuests.pop();
                break;
            }
        }

        totalQuestsCompleted++;

        emit QuestCompleted(questId, msg.sender, quest.experienceReward, quest.reputationReward);
    }

    /**
     * @dev Updates NPC dialogue
     * @param newGreeting New greeting message
     * @param newResponses Array of response messages
     * @param newMood New mood (0-3)
     */
    function updateDialogue(
        string memory newGreeting,
        string[] memory newResponses,
        uint8 newMood
    ) external onlyOwner {
        require(bytes(newGreeting).length > 0, "GameAgent: greeting cannot be empty");
        require(newMood <= 3, "GameAgent: invalid mood");

        dialogue.greeting = newGreeting;
        dialogue.responses = newResponses;
        dialogue.mood = newMood;

        emit DialogueUpdated(dialogue.dialogueId, newGreeting, newMood);
    }

    /**
     * @dev Records a player interaction
     * @param player Player address
     * @param responseIndex Index of the response given
     */
    function recordInteraction(address player, uint256 responseIndex) external {
        require(player != address(0), "GameAgent: invalid player address");

        if (!interactedPlayers.contains(player)) {
            playerInteractions[player] = PlayerInteraction({
                player: player,
                interactionCount: 0,
                lastInteraction: 0,
                reputationWithAgent: 100,
                hasActiveQuest: false,
                completedQuests: new uint256[](0),
                activeQuests: new uint256[](0)
            });
            interactedPlayers.add(player);
        }

        PlayerInteraction storage interaction = playerInteractions[player];
        require(
            block.timestamp >= interaction.lastInteraction + interactionCooldown,
            "GameAgent: interaction cooldown active"
        );

        interaction.interactionCount++;
        interaction.lastInteraction = block.timestamp;

        dialogue.lastInteraction = block.timestamp;
        dialogue.interactionCount++;
        totalInteractions++;

        emit PlayerInteracted(player, dialogue.mood, interaction.interactionCount);
    }

    /**
     * @dev Creates a trade offer
     * @param offerItems Array of items to offer
     * @param offerQuantities Array of quantities to offer
     * @param requestItems Array of items requested
     * @param requestQuantities Array of quantities requested
     * @param deadline Trade deadline
     */
    function createTradeOffer(
        uint256[] memory offerItems,
        uint256[] memory offerQuantities,
        uint256[] memory requestItems,
        uint256[] memory requestQuantities,
        uint256 deadline
    ) external {
        require(acceptsTrades, "GameAgent: trades not accepted");
        require(offerItems.length == offerQuantities.length, "GameAgent: arrays length mismatch");
        require(
            requestItems.length == requestQuantities.length,
            "GameAgent: arrays length mismatch"
        );
        require(deadline > block.timestamp, "GameAgent: invalid deadline");

        _tradeOfferIdCounter.increment();
        uint256 offerId = _tradeOfferIdCounter.current();

        tradeOffers[offerId] = TradeOffer({
            offerId: offerId,
            trader: msg.sender,
            offerItems: offerItems,
            offerQuantities: offerQuantities,
            requestItems: requestItems,
            requestQuantities: requestQuantities,
            deadline: deadline,
            isActive: true,
            isCompleted: false
        });

        activeTradeOffers.add(offerId);

        emit TradeOfferCreated(offerId, msg.sender, offerItems, requestItems);
    }

    /**
     * @dev Accepts a trade offer
     * @param offerId Trade offer ID to accept
     */
    function acceptTradeOffer(uint256 offerId) external nonReentrant {
        require(tradeOffers[offerId].offerId != 0, "GameAgent: trade offer does not exist");
        require(tradeOffers[offerId].isActive, "GameAgent: trade offer is not active");
        require(!tradeOffers[offerId].isCompleted, "GameAgent: trade offer already completed");
        require(block.timestamp <= tradeOffers[offerId].deadline, "GameAgent: trade offer expired");

        TradeOffer storage offer = tradeOffers[offerId];
        require(offer.trader != msg.sender, "GameAgent: cannot accept own offer");

        // Mark trade as completed
        offer.isCompleted = true;
        offer.isActive = false;
        activeTradeOffers.remove(offerId);

        totalItemsTraded += offer.offerItems.length + offer.requestItems.length;
        totalValueTraded +=
            calculateTradeValue(offer.offerItems, offer.offerQuantities) +
            calculateTradeValue(offer.requestItems, offer.requestQuantities);

        emit TradeOfferAccepted(offerId, msg.sender, offer.trader);
    }

    // ============ LEARNING MODULE INTEGRATION ============

    /**
     * @dev Sets the learning module address
     * @param learningModuleAddress Address of the learning module
     */
    function setLearningModule(address learningModuleAddress) external onlyOwner {
        learningModule = learningModuleAddress;
        learningEnabled = learningModuleAddress != address(0);
    }

    /**
     * @dev Records learning data for the agent
     * @param dataType Type of learning data
     * @param dataHash Hash of the learning data
     */
    function recordLearningData(string memory dataType, bytes32 dataHash) external onlyOwner {
        require(learningEnabled, "GameAgent: learning not enabled");

        emit LearningUpdate(dataType, dataHash, block.timestamp);
    }

    /**
     * @dev Updates agent behavior based on learning
     * @param newBehaviorData New behavior configuration
     */
    function updateBehavior(bytes32 newBehaviorData) external onlyOwner {
        require(learningEnabled, "GameAgent: learning not enabled");

        // This would integrate with the learning module to update agent behavior
        emit LearningUpdate("behavior_update", newBehaviorData, block.timestamp);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Gets the agent's inventory
     * @return Array of item IDs in inventory
     */
    function getInventory() external view returns (uint256[] memory) {
        return itemIds.values();
    }

    /**
     * @dev Gets item details
     * @param itemId Item ID
     * @return Item details
     */
    function getItem(uint256 itemId) external view validItem(itemId) returns (Item memory) {
        return items[itemId];
    }

    /**
     * @dev Gets all active quests
     * @return Array of active quest IDs
     */
    function getActiveQuests() external view returns (uint256[] memory) {
        return activeQuests.values();
    }

    /**
     * @dev Gets quest details
     * @param questId Quest ID
     * @return Quest details
     */
    function getQuest(uint256 questId) external view validQuest(questId) returns (Quest memory) {
        return quests[questId];
    }

    /**
     * @dev Gets player interaction data
     * @param player Player address
     * @return Player interaction data
     */
    function getPlayerInteraction(address player) external view returns (PlayerInteraction memory) {
        return playerInteractions[player];
    }

    /**
     * @dev Gets all players who have interacted with the agent
     * @return Array of player addresses
     */
    function getInteractedPlayers() external view returns (address[] memory) {
        return interactedPlayers.values();
    }

    /**
     * @dev Gets all active trade offers
     * @return Array of active trade offer IDs
     */
    function getActiveTradeOffers() external view returns (uint256[] memory) {
        return activeTradeOffers.values();
    }

    /**
     * @dev Gets agent statistics
     * @return Total interactions, quests given, quests completed, items traded, value traded
     */
    function getAgentStatistics()
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256)
    {
        return (
            totalInteractions,
            totalQuestsGiven,
            totalQuestsCompleted,
            totalItemsTraded,
            totalValueTraded
        );
    }

    /**
     * @dev Gets agent profile
     * @return Agent profile
     */
    function getAgentProfile() external view returns (AgentProfile memory) {
        return profile;
    }

    /**
     * @dev Gets NPC dialogue
     * @return NPC dialogue data
     */
    function getDialogue() external view returns (NPCDialogue memory) {
        return dialogue;
    }

    // ============ UTILITY FUNCTIONS ============

    /**
     * @dev Calculates the value of a trade
     * @param itemIds Array of item IDs
     * @param quantities Array of quantities
     * @return Total value of the trade
     */
    function calculateTradeValue(
        uint256[] memory itemIds,
        uint256[] memory quantities
    ) internal view returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < itemIds.length; i++) {
            if (itemIds[i] != 0 && items[itemIds[i]].itemId != 0) {
                totalValue += items[itemIds[i]].value * quantities[i];
            }
        }
        return totalValue;
    }

    /**
     * @dev Updates agent configuration
     * @param newMaxInventory New maximum inventory size
     * @param newMaxActiveQuests New maximum active quests
     * @param newInteractionCooldown New interaction cooldown
     * @param newAcceptsTrades Whether agent accepts trades
     * @param newAcceptsQuests Whether agent accepts quests
     */
    function updateConfiguration(
        uint256 newMaxInventory,
        uint256 newMaxActiveQuests,
        uint256 newInteractionCooldown,
        bool newAcceptsTrades,
        bool newAcceptsQuests
    ) external onlyOwner {
        require(newMaxInventory > 0, "GameAgent: max inventory must be greater than 0");
        require(newMaxActiveQuests > 0, "GameAgent: max active quests must be greater than 0");

        maxInventorySize = newMaxInventory;
        maxActiveQuests = newMaxActiveQuests;
        interactionCooldown = newInteractionCooldown;
        acceptsTrades = newAcceptsTrades;
        acceptsQuests = newAcceptsQuests;
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ EMERGENCY FUNCTIONS ============

    /**
     * @dev Emergency function to deactivate the agent
     */
    function deactivateAgent() external onlyOwner {
        profile.isActive = false;
        acceptsTrades = false;
        acceptsQuests = false;
    }

    /**
     * @dev Emergency function to reactivate the agent
     */
    function reactivateAgent() external onlyOwner {
        profile.isActive = true;
        acceptsTrades = true;
        acceptsQuests = true;
    }
}
