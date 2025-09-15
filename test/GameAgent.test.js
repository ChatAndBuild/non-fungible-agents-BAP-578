const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("GameAgent Template Integration", function () {
  let GameAgent;
  let BAP578;
  let CircuitBreaker;
  let gameAgent;
  let bap578;
  let circuitBreaker;
  let owner;
  let addr1;
  let addr2;
  let addr3;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // Deploy CircuitBreaker
    CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
    circuitBreaker = await CircuitBreaker.deploy();
    await circuitBreaker.deployed();

    // Deploy BAP578
    BAP578 = await ethers.getContractFactory("BAP578");
    bap578 = await upgrades.deployProxy(
      BAP578,
      ["Non-Fungible Agent", "NFA", circuitBreaker.address],
      { initializer: "initialize", kind: "uups" }
    );
    await bap578.deployed();

    // Deploy GameAgent
    GameAgent = await ethers.getContractFactory("GameAgent");
    gameAgent = await GameAgent.deploy(
      bap578.address,
      "Gaming NPC",
      "Fantasy World",
      "Merchant",
      100 // max inventory
    );
    await gameAgent.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right agent token address", async function () {
      expect(await gameAgent.agentToken()).to.equal(bap578.address);
    });

    it("Should initialize with correct profile", async function () {
      const profile = await gameAgent.getAgentProfile();
      expect(profile.name).to.equal("Gaming NPC");
      expect(profile.gameWorld).to.equal("Fantasy World");
      expect(profile.characterClass).to.equal("Merchant");
      expect(profile.level).to.equal(1);
      expect(profile.experience).to.equal(0);
      expect(profile.reputation).to.equal(100);
      expect(profile.isActive).to.equal(true);
    });

    it("Should initialize with correct configuration", async function () {
      expect(await gameAgent.maxInventorySize()).to.equal(100);
      expect(await gameAgent.maxActiveQuests()).to.equal(10);
      expect(await gameAgent.interactionCooldown()).to.equal(300);
      expect(await gameAgent.acceptsTrades()).to.equal(true);
      expect(await gameAgent.acceptsQuests()).to.equal(true);
    });

    it("Should initialize with default dialogue", async function () {
      const dialogue = await gameAgent.getDialogue();
      expect(dialogue.greeting).to.equal("Greetings, traveler!");
      expect(dialogue.mood).to.equal(0);
      expect(dialogue.interactionCount).to.equal(0);
    });

    it("Should reject deployment with invalid parameters", async function () {
      await expect(
        GameAgent.deploy(
          ethers.constants.AddressZero,
          "Test",
          "World",
          "Class",
          100
        )
      ).to.be.revertedWith("GameAgent: invalid agent token address");

      await expect(
        GameAgent.deploy(
          bap578.address,
          "",
          "World",
          "Class",
          100
        )
      ).to.be.revertedWith("GameAgent: name cannot be empty");

      await expect(
        GameAgent.deploy(
          bap578.address,
          "Test",
          "",
          "Class",
          100
        )
      ).to.be.revertedWith("GameAgent: game world cannot be empty");

      await expect(
        GameAgent.deploy(
          bap578.address,
          "Test",
          "World",
          "Class",
          0
        )
      ).to.be.revertedWith("GameAgent: max inventory must be greater than 0");
    });
  });

  describe("Profile Management", function () {
    it("Should allow owner to update profile", async function () {
      await gameAgent.updateProfile(
        "Updated NPC",
        "A helpful merchant",
        5
      );

      const profile = await gameAgent.getAgentProfile();
      expect(profile.name).to.equal("Updated NPC");
      expect(profile.description).to.equal("A helpful merchant");
      expect(profile.level).to.equal(5);
    });

    it("Should reject invalid profile updates", async function () {
      await expect(
        gameAgent.updateProfile("", "Description", 1)
      ).to.be.revertedWith("GameAgent: name cannot be empty");

      await expect(
        gameAgent.updateProfile("Name", "Description", 0)
      ).to.be.revertedWith("GameAgent: level must be greater than 0");
    });

    it("Should reject profile updates from non-owner", async function () {
      await expect(
        gameAgent.connect(addr1).updateProfile("Name", "Description", 1)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Item Management", function () {
    it("Should allow owner to add items", async function () {
      await gameAgent.addItem(
        "Health Potion",
        "Restores 50 HP",
        2, // Consumable
        1, // Common
        100, // Value
        10, // Quantity
        true, // Tradeable
        true // Craftable
      );

      const inventory = await gameAgent.getInventory();
      expect(inventory.length).to.equal(1);

      const item = await gameAgent.getItem(inventory[0]);
      expect(item.name).to.equal("Health Potion");
      expect(item.description).to.equal("Restores 50 HP");
      expect(item.itemType).to.equal(2);
      expect(item.rarity).to.equal(1);
      expect(item.value).to.equal(100);
      expect(item.quantity).to.equal(10);
      expect(item.isTradeable).to.equal(true);
      expect(item.isCraftable).to.equal(true);
    });

    it("Should allow owner to remove items", async function () {
      await gameAgent.addItem(
        "Health Potion",
        "Restores 50 HP",
        2,
        1,
        100,
        10,
        true,
        true
      );

      const inventory = await gameAgent.getInventory();
      const itemId = inventory[0];

      await gameAgent.removeItem(itemId, 5);

      const item = await gameAgent.getItem(itemId);
      expect(item.quantity).to.equal(5);

      await gameAgent.removeItem(itemId, 5);

      const newInventory = await gameAgent.getInventory();
      expect(newInventory.length).to.equal(0);
    });

    it("Should reject invalid item operations", async function () {
      await expect(
        gameAgent.addItem(
          "",
          "Description",
          0,
          1,
          100,
          10,
          true,
          true
        )
      ).to.be.revertedWith("GameAgent: item name cannot be empty");

      await expect(
        gameAgent.addItem(
          "Item",
          "Description",
          5, // Invalid type
          1,
          100,
          10,
          true,
          true
        )
      ).to.be.revertedWith("GameAgent: invalid item type");

      await expect(
        gameAgent.addItem(
          "Item",
          "Description",
          0,
          0, // Invalid rarity
          100,
          10,
          true,
          true
        )
      ).to.be.revertedWith("GameAgent: invalid rarity");

      await expect(
        gameAgent.addItem(
          "Item",
          "Description",
          0,
          1,
          100,
          0, // Invalid quantity
          true,
          true
        )
      ).to.be.revertedWith("GameAgent: quantity must be greater than 0");
    });

    it("Should reject item operations from non-owner", async function () {
      await expect(
        gameAgent.connect(addr1).addItem(
          "Item",
          "Description",
          0,
          1,
          100,
          10,
          true,
          true
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        gameAgent.connect(addr1).removeItem(1, 1)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should respect inventory limits", async function () {
      // Add items up to the limit
      for (let i = 0; i < 100; i++) {
        await gameAgent.addItem(
          `Item ${i}`,
          `Description ${i}`,
          0,
          1,
          100,
          1,
          true,
          true
        );
      }

      // Try to add one more item
      await expect(
        gameAgent.addItem(
          "Extra Item",
          "Description",
          0,
          1,
          100,
          1,
          true,
          true
        )
      ).to.be.revertedWith("GameAgent: inventory limit exceeded");
    });
  });

  describe("Quest System", function () {
    beforeEach(async function () {
      // Add some items for quest requirements and rewards
      await gameAgent.addItem(
        "Health Potion",
        "Restores 50 HP",
        2,
        1,
        100,
        20,
        true,
        true
      );

      await gameAgent.addItem(
        "Gold Coin",
        "Currency",
        4,
        1,
        1,
        1000,
        true,
        false
      );
    });

    it("Should allow owner to create quests", async function () {
      const inventory = await gameAgent.getInventory();
      const healthPotionId = inventory[0];
      const goldCoinId = inventory[1];

      await gameAgent.createQuest(
        "Collect Health Potions",
        "Bring me 5 health potions",
        1, // Collect quest
        [healthPotionId],
        [5],
        [goldCoinId],
        [100],
        50, // Experience reward
        10, // Reputation reward
        0 // No deadline
      );

      const activeQuests = await gameAgent.getActiveQuests();
      expect(activeQuests.length).to.equal(1);

      const quest = await gameAgent.getQuest(activeQuests[0]);
      expect(quest.title).to.equal("Collect Health Potions");
      expect(quest.description).to.equal("Bring me 5 health potions");
      expect(quest.questType).to.equal(1);
      expect(quest.requiredItems.length).to.equal(1);
      expect(quest.requiredQuantities[0]).to.equal(5);
      expect(quest.rewardItems.length).to.equal(1);
      expect(quest.rewardQuantities[0]).to.equal(100);
      expect(quest.experienceReward).to.equal(50);
      expect(quest.reputationReward).to.equal(10);
      expect(quest.isActive).to.equal(true);
      expect(quest.isCompleted).to.equal(false);
    });

    it("Should allow players to accept quests", async function () {
      const inventory = await gameAgent.getInventory();
      const healthPotionId = inventory[0];
      const goldCoinId = inventory[1];

      await gameAgent.createQuest(
        "Collect Health Potions",
        "Bring me 5 health potions",
        1,
        [healthPotionId],
        [5],
        [goldCoinId],
        [100],
        50,
        10,
        0
      );

      const activeQuests = await gameAgent.getActiveQuests();
      const questId = activeQuests[0];

      await gameAgent.connect(addr1).acceptQuest(questId);

      const quest = await gameAgent.getQuest(questId);
      expect(quest.questTaker).to.equal(addr1.address);

      const playerInteraction = await gameAgent.getPlayerInteraction(addr1.address);
      expect(playerInteraction.hasActiveQuest).to.equal(true);
      expect(playerInteraction.activeQuests.length).to.equal(1);
    });

    it("Should allow players to complete quests", async function () {
      const inventory = await gameAgent.getInventory();
      const healthPotionId = inventory[0];
      const goldCoinId = inventory[1];

      await gameAgent.createQuest(
        "Collect Health Potions",
        "Bring me 5 health potions",
        1,
        [healthPotionId],
        [5],
        [goldCoinId],
        [100],
        50,
        10,
        0
      );

      const activeQuests = await gameAgent.getActiveQuests();
      const questId = activeQuests[0];

      await gameAgent.connect(addr1).acceptQuest(questId);
      await gameAgent.connect(addr1).completeQuest(
        questId,
        [healthPotionId],
        [5]
      );

      const quest = await gameAgent.getQuest(questId);
      expect(quest.isCompleted).to.equal(true);
      expect(quest.isActive).to.equal(false);

      const playerInteraction = await gameAgent.getPlayerInteraction(addr1.address);
      expect(playerInteraction.hasActiveQuest).to.equal(false);
      expect(playerInteraction.completedQuests.length).to.equal(1);
      expect(playerInteraction.reputationWithAgent).to.equal(110); // 100 + 10
    });

    it("Should reject invalid quest operations", async function () {
      await expect(
        gameAgent.createQuest(
          "",
          "Description",
          0,
          [],
          [],
          [],
          [],
          0,
          0,
          0
        )
      ).to.be.revertedWith("GameAgent: quest title cannot be empty");

      await expect(
        gameAgent.createQuest(
          "Title",
          "Description",
          5, // Invalid quest type
          [],
          [],
          [],
          [],
          0,
          0,
          0
        )
      ).to.be.revertedWith("GameAgent: invalid quest type");

      await expect(
        gameAgent.createQuest(
          "Title",
          "Description",
          0,
          [1],
          [1, 2], // Mismatched arrays
          [],
          [],
          0,
          0,
          0
        )
      ).to.be.revertedWith("GameAgent: arrays length mismatch");
    });

    it("Should reject quest operations from non-owner", async function () {
      await expect(
        gameAgent.connect(addr1).createQuest(
          "Title",
          "Description",
          0,
          [],
          [],
          [],
          [],
          0,
          0,
          0
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("NPC Dialogue System", function () {
    it("Should allow owner to update dialogue", async function () {
      const newResponses = ["Response 1", "Response 2", "Response 3"];
      
      await gameAgent.updateDialogue(
        "Hello there!",
        newResponses,
        1 // Friendly mood
      );

      const dialogue = await gameAgent.getDialogue();
      expect(dialogue.greeting).to.equal("Hello there!");
      expect(dialogue.responses.length).to.equal(3);
      expect(dialogue.mood).to.equal(1);
    });

    it("Should allow recording player interactions", async function () {
      await gameAgent.recordInteraction(addr1.address, 0);

      const dialogue = await gameAgent.getDialogue();
      expect(dialogue.interactionCount).to.equal(1);
      expect(dialogue.lastInteraction).to.be.a('object');
      expect(dialogue.lastInteraction.toNumber()).to.be.greaterThan(0);

      const playerInteraction = await gameAgent.getPlayerInteraction(addr1.address);
      expect(playerInteraction.interactionCount).to.equal(1);
      expect(playerInteraction.lastInteraction).to.be.a('object');
      expect(playerInteraction.lastInteraction.toNumber()).to.be.greaterThan(0);
    });

    it("Should respect interaction cooldown", async function () {
      await gameAgent.recordInteraction(addr1.address, 0);

      await expect(
        gameAgent.recordInteraction(addr1.address, 0)
      ).to.be.revertedWith("GameAgent: interaction cooldown active");
    });

    it("Should reject invalid dialogue updates", async function () {
      await expect(
        gameAgent.updateDialogue(
          "",
          [],
          0
        )
      ).to.be.revertedWith("GameAgent: greeting cannot be empty");

      await expect(
        gameAgent.updateDialogue(
          "Greeting",
          [],
          4 // Invalid mood
        )
      ).to.be.revertedWith("GameAgent: invalid mood");
    });

    it("Should reject dialogue updates from non-owner", async function () {
      await expect(
        gameAgent.connect(addr1).updateDialogue(
          "Greeting",
          [],
          0
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Trading System", function () {
    beforeEach(async function () {
      // Add items for trading
      await gameAgent.addItem(
        "Health Potion",
        "Restores 50 HP",
        2,
        1,
        100,
        20,
        true,
        true
      );

      await gameAgent.addItem(
        "Gold Coin",
        "Currency",
        4,
        1,
        1,
        1000,
        true,
        false
      );
    });

    it("Should allow creating trade offers", async function () {
      const inventory = await gameAgent.getInventory();
      const healthPotionId = inventory[0];
      const goldCoinId = inventory[1];

      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

      await gameAgent.connect(addr1).createTradeOffer(
        [healthPotionId],
        [5],
        [goldCoinId],
        [100],
        deadline
      );

      const activeTradeOffers = await gameAgent.getActiveTradeOffers();
      expect(activeTradeOffers.length).to.equal(1);

      const offerId = activeTradeOffers[0];
      expect(offerId).to.not.be.undefined;
      
      const tradeOffer = await gameAgent.tradeOffers(offerId);
      expect(tradeOffer.trader).to.equal(addr1.address);
      expect(tradeOffer.isActive).to.equal(true);
      expect(tradeOffer.isCompleted).to.equal(false);
      expect(tradeOffer.deadline).to.be.a('object');
      expect(tradeOffer.deadline.toNumber()).to.be.greaterThan(0);
    });

    it("Should allow accepting trade offers", async function () {
      const inventory = await gameAgent.getInventory();
      const healthPotionId = inventory[0];
      const goldCoinId = inventory[1];

      const deadline = Math.floor(Date.now() / 1000) + 3600;

      await gameAgent.connect(addr1).createTradeOffer(
        [healthPotionId],
        [5],
        [goldCoinId],
        [100],
        deadline
      );

      const activeTradeOffers = await gameAgent.getActiveTradeOffers();
      const offerId = activeTradeOffers[0];

      await gameAgent.connect(addr2).acceptTradeOffer(offerId);

      const tradeOffer = await gameAgent.tradeOffers(offerId);
      expect(tradeOffer.isCompleted).to.equal(true);
      expect(tradeOffer.isActive).to.equal(false);
    });

    it("Should reject invalid trade operations", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      await expect(
        gameAgent.connect(addr1).createTradeOffer(
          [1],
          [1, 2], // Mismatched arrays
          [2],
          [1],
          deadline
        )
      ).to.be.revertedWith("GameAgent: arrays length mismatch");

      await expect(
        gameAgent.connect(addr1).createTradeOffer(
          [1],
          [1],
          [2],
          [1, 2], // Mismatched arrays
          deadline
        )
      ).to.be.revertedWith("GameAgent: arrays length mismatch");

      await expect(
        gameAgent.connect(addr1).createTradeOffer(
          [1],
          [1],
          [2],
          [1],
          Math.floor(Date.now() / 1000) - 3600 // Past deadline
        )
      ).to.be.revertedWith("GameAgent: invalid deadline");
    });

    it("Should reject accepting own trade offers", async function () {
      const inventory = await gameAgent.getInventory();
      const healthPotionId = inventory[0];
      const goldCoinId = inventory[1];

      const deadline = Math.floor(Date.now() / 1000) + 3600;

      await gameAgent.connect(addr1).createTradeOffer(
        [healthPotionId],
        [5],
        [goldCoinId],
        [100],
        deadline
      );

      const activeTradeOffers = await gameAgent.getActiveTradeOffers();
      const offerId = activeTradeOffers[0];

      await expect(
        gameAgent.connect(addr1).acceptTradeOffer(offerId)
      ).to.be.revertedWith("GameAgent: cannot accept own offer");
    });
  });

  describe("Learning Module Integration", function () {
    it("Should allow setting learning module", async function () {
      await gameAgent.setLearningModule(addr1.address);

      expect(await gameAgent.learningModule()).to.equal(addr1.address);
      expect(await gameAgent.learningEnabled()).to.equal(true);
    });

    it("Should allow recording learning data", async function () {
      await gameAgent.setLearningModule(addr1.address);

      const dataHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test data"));
      
      await expect(
        gameAgent.recordLearningData("interaction_data", dataHash)
      ).to.not.be.reverted;
    });

    it("Should allow updating behavior", async function () {
      await gameAgent.setLearningModule(addr1.address);

      const behaviorData = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("new behavior"));

      await expect(
        gameAgent.updateBehavior(behaviorData)
      ).to.not.be.reverted;
    });

    it("Should reject learning operations when disabled", async function () {
      const dataHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test data"));
      
      await expect(
        gameAgent.recordLearningData("interaction_data", dataHash)
      ).to.be.revertedWith("GameAgent: learning not enabled");

      const behaviorData = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("new behavior"));

      await expect(
        gameAgent.updateBehavior(behaviorData)
      ).to.be.revertedWith("GameAgent: learning not enabled");
    });

    it("Should reject learning operations from non-owner", async function () {
      await gameAgent.setLearningModule(addr1.address);

      const dataHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test data"));

      await expect(
        gameAgent.connect(addr1).recordLearningData("interaction_data", dataHash)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      const behaviorData = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("new behavior"));

      await expect(
        gameAgent.connect(addr1).updateBehavior(behaviorData)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("View Functions", function () {
    beforeEach(async function () {
      // Add some items
      await gameAgent.addItem("Item 1", "Description 1", 0, 1, 100, 10, true, true);
      await gameAgent.addItem("Item 2", "Description 2", 1, 2, 200, 5, true, false);

      // Create a quest
      const inventory = await gameAgent.getInventory();
      await gameAgent.createQuest(
        "Test Quest",
        "Test Description",
        0,
        [inventory[0]],
        [1],
        [inventory[1]],
        [1],
        10,
        5,
        0
      );

      // Note: Interactions are tested separately to avoid cooldown issues
    });

    it("Should return correct inventory", async function () {
      const inventory = await gameAgent.getInventory();
      expect(inventory.length).to.equal(2);
    });

    it("Should return correct active quests", async function () {
      const activeQuests = await gameAgent.getActiveQuests();
      expect(activeQuests.length).to.equal(1);
    });

    it("Should return correct interacted players", async function () {
      const interactedPlayers = await gameAgent.getInteractedPlayers();
      expect(interactedPlayers.length).to.equal(0); // No interactions recorded in beforeEach
    });

    it("Should return correct agent statistics", async function () {
      const stats = await gameAgent.getAgentStatistics();
      expect(stats[0]).to.equal(0); // totalInteractions
      expect(stats[1]).to.equal(1); // totalQuestsGiven
      expect(stats[2]).to.equal(0); // totalQuestsCompleted
      expect(stats[3]).to.equal(0); // totalItemsTraded
      expect(stats[4]).to.equal(0); // totalValueTraded
    });
  });

  describe("Configuration Management", function () {
    it("Should allow owner to update configuration", async function () {
      await gameAgent.updateConfiguration(
        200, // maxInventory
        20,  // maxActiveQuests
        600, // interactionCooldown
        false, // acceptsTrades
        false  // acceptsQuests
      );

      expect(await gameAgent.maxInventorySize()).to.equal(200);
      expect(await gameAgent.maxActiveQuests()).to.equal(20);
      expect(await gameAgent.interactionCooldown()).to.equal(600);
      expect(await gameAgent.acceptsTrades()).to.equal(false);
      expect(await gameAgent.acceptsQuests()).to.equal(false);
    });

    it("Should reject invalid configuration updates", async function () {
      await expect(
        gameAgent.updateConfiguration(
          0, // Invalid maxInventory
          20,
          600,
          true,
          true
        )
      ).to.be.revertedWith("GameAgent: max inventory must be greater than 0");

      await expect(
        gameAgent.updateConfiguration(
          100,
          0, // Invalid maxActiveQuests
          600,
          true,
          true
        )
      ).to.be.revertedWith("GameAgent: max active quests must be greater than 0");
    });

    it("Should reject configuration updates from non-owner", async function () {
      await expect(
        gameAgent.connect(addr1).updateConfiguration(
          200,
          20,
          600,
          false,
          false
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Emergency Functions", function () {
    it("Should allow owner to pause and unpause", async function () {
      await gameAgent.pause();
      expect(await gameAgent.paused()).to.equal(true);

      await gameAgent.unpause();
      expect(await gameAgent.paused()).to.equal(false);
    });

    it("Should allow owner to deactivate and reactivate agent", async function () {
      await gameAgent.deactivateAgent();
      
      const profile = await gameAgent.getAgentProfile();
      expect(profile.isActive).to.equal(false);
      expect(await gameAgent.acceptsTrades()).to.equal(false);
      expect(await gameAgent.acceptsQuests()).to.equal(false);

      await gameAgent.reactivateAgent();
      
      const updatedProfile = await gameAgent.getAgentProfile();
      expect(updatedProfile.isActive).to.equal(true);
      expect(await gameAgent.acceptsTrades()).to.equal(true);
      expect(await gameAgent.acceptsQuests()).to.equal(true);
    });

    it("Should reject emergency functions from non-owner", async function () {
      await expect(
        gameAgent.connect(addr1).pause()
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        gameAgent.connect(addr1).unpause()
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        gameAgent.connect(addr1).deactivateAgent()
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        gameAgent.connect(addr1).reactivateAgent()
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("BAP-578 Integration", function () {
    it("Should work with BAP-578 agent creation", async function () {
      // Create an agent using the GameAgent template
      const metadataURI = "ipfs://game-agent-metadata";
      const extendedMetadata = {
        persona: "A helpful merchant NPC in the fantasy world",
        experience: "Expert in item trading and quest giving",
        voiceHash: "voice_hash_reference",
        animationURI: "ipfs://game-agent-animation",
        vaultURI: "ipfs://game-agent-vault",
        vaultHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("vault_content"))
      };

      // This would be called by the AgentFactory in a real scenario
      const agentCreationTx = await bap578['createAgent(address,address,string,(string,string,string,string,string,bytes32))'](
        owner.address,     // creator
        gameAgent.address, // template address
        metadataURI,       // metadata URI
        extendedMetadata   // extended metadata
      );

      await agentCreationTx.wait();

      // Verify the agent was created
      const totalSupply = await bap578.totalSupply();
      expect(totalSupply).to.equal(1);
    });
  });
});