--[[
	Name: Polychromatic
	Author: Wobin
	Date: 26/09/2026
]]--

local mod = get_mod("Polychromatic")
mod.version = mod.get_metadata and mod:get_metadata("version") or "unknown"

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local World = World
local World_are_particles_playing = World.are_particles_playing
local World_has_particles_material = World.has_particles_material
local World_set_particles_material_scalar = World.set_particles_material_scalar
local World_set_particles_material_vector3 = World.set_particles_material_vector3
local World_stop_spawning_particles = World.stop_spawning_particles
local get_mod = get_mod

local REDIRECTS = {
	{
		stock = "data/80/809f0435f2b74af3",
		file = "809f0435f2b74af3.livehsv",
		sha256 = "6c281be550d37d8ba3cb765199619bbaf81eb0d0365251a21dd9835e1621dfaf",
	},
	{
		stock = "data/85/85d24accc98ef272",
		file = "85d24accc98ef272.livehsv2",
		sha256 = "1cf95fd9e9ac6afa6370849696d67a4cc602f369e0c6c8310409f18479c46ece",
	},
	{
		stock = "data/03/03f68803faf03b51",
		file = "03f68803faf03b51.livehsv",
		sha256 = "73943bfb02628b95f6e822cddfea241e87feaa7849080f157952a012cb7efce3",
	},
	{
		stock = "4e6163c275b96d00",
		file = "4e6163c275b96d00.pyro",
		sha256 = "1bdf1a5b90e324da137b98a9d971902ad206cd7d55b59b5d218ba6edd67b6d51",
	},
	{
		stock = "bf83ff6f40d45fc8",
		file = "bf83ff6f40d45fc8.pyro2",
		sha256 = "65fcde9a26dd0eb18c5d1dcab9e910908bb6d32b3802bea5bb7286c47849e153",
	},
	{
		stock = "data/53/533194479779e27b",
		file = "533194479779e27b.livehsv",
		sha256 = "2a0b46efa9255d0912e32b1467dd9d2a70b6cbfc1ac0c17eb9b9228b33f8b03f",
	},
	{
		stock = "data/ae/ae9963d8c98fe6b6",
		file = "ae9963d8c98fe6b6.livehsv",
		sha256 = "16abe7f4287fc08708fc2d87d52eee1c1a1909a361628c89fcdb8dc0f5637e1d",
	},
	{
		stock = "data/18/186941c392bb5d7b",
		file = "186941c392bb5d7b.livehsv",
		sha256 = "63e9c6eea5bee9497a80578ad3f08015c77a1b910083925602f2d6c21a804a2f",
	},
	{
		stock = "e605c5550cf3088b",
		file = "e605c5550cf3088b.pyro",
		sha256 = "eb74db948d7983eeb7ba6c27fbeaa3562d2f9c7dada83b8176f09a6145fa9743",
	},
	{
		stock = "f3952b5fba574342",
		file = "f3952b5fba574342.pyro",
		sha256 = "d9e012a29d3f9193690fd187b01eb1bad35899dac7a8a252a5a57f2ed78cf0bd",
	},
	{
		stock = "299f23117d653583",
		file = "299f23117d653583.pyro",
		sha256 = "debb237ed0d16f6fed4adb2640bbf8ac398e9f8ec93f11f7a1cb432c01a114b8",
	},
	{
		stock = "53ef9473070da411",
		file = "53ef9473070da411.pyro",
		sha256 = "dad0ba2d6bb84c5ec60f1ba73e486784f2e1c17845fd993c4cdc79c7d4a79fff",
	},
	{
		stock = "data/a4/a40299ecf616514c",
		file = "a40299ecf616514c.livehsv",
		sha256 = "a5c007c5b0af581b834d62b5053237a56888da2d575666461fefc77ab9665e32",
	},
	{
		stock = "data/15/150a4ba090c95379",
		file = "5b86a311c0ac5cf0.livehsv",
		sha256 = "b0d07a50a284eef05e15a03f1425008d1cf287308723464ee6059949a8bdd7cf",
	},
	{
		stock = "data/19/19bcec6ae1991184",
		file = "3586b12003ab11fc.livehsv",
		sha256 = "7d64c7f1e068f904606dcba5bd1579b22789964ed0c83cda0575e6d4b25047aa",
	},
	{
		stock = "data/6b/6bcf952c725f6a2f",
		file = "6bcf952c725f6a2f.livehsv",
		sha256 = "9df2110d0846b64911ed248161871fcb24c4ffab73ea2fcb90bc3338a6d64766",
	},
	{
		stock = "28d55df9efb7f8e5",
		file = "28d55df9efb7f8e5.pyro",
		sha256 = "6dc3d1bc3fa65afd02b1b965d419d37a3d3978cd078f2fda3de263c849ba072e",
	},
	{
		stock = "30ebeee18093c079",
		file = "30ebeee18093c079.pyro",
		sha256 = "53fd3e19870d70e18377151233f3aa3a141ead0339c55ad4dd83b4625fa5e531",
	},
	{
		stock = "data/bb/bb79ba7a5b92d132",
		file = "bb79ba7a5b92d132.livehsv",
		sha256 = "7e072a559e0c2d77f762c12bde0214521e925d235e2ae17c75ff7605f9a6b35c",
	},
	{
		stock = "data/af/af395bb3270f316d",
		file = "af395bb3270f316d.livehsv",
		sha256 = "d8830c0a00bf2aef2fdaa60ca4f54db7f623428d981f67a02fa81e8953ce42fd",
	},
	{
		stock = "97498862fb42b0d6",
		file = "97498862fb42b0d6.pyro",
		sha256 = "7d48b146e33c023586c37e427c3e941063f86801ce8b0047f962f193bd746dad",
	},
	{
		stock = "3d487cca8bd5c544",
		file = "3d487cca8bd5c544.pyro",
		sha256 = "c04e6a56e333d5bd3e437e36b45bf39cb1588db5504776319f9f53d936195afa",
	},
}

local LAS_REDIRECTS = {
	{
		stock = "data/00/0028686adad0c743",
		file = "0028686adad0c743.livehsv",
		sha256 = "5b78d0b55b7b120b2041c9808e25861e0d90cf386159e086a71c156bdf9a3d36",
	},
	{
		stock = "data/3c/3c5cb0cf7d5047c8",
		file = "3c5cb0cf7d5047c8.livehsv",
		sha256 = "eec7014da4cbfecc133988911247e95aa89d5562f121e1035d27cd0a5d5e1bd4",
	},
	{
		stock = "data/61/61446d60d543f9db",
		file = "61446d60d543f9db.livehsv",
		sha256 = "6c1586750d616fca428c02fb3da8eccef763f56b76682c49cab0573aa29c4b7e",
	},
	{
		stock = "data/70/7082301abe176951",
		file = "7082301abe176951.livehsv",
		sha256 = "85c23556b3b3ea98383c7c7b2077e65ace5049d7c8433fbb7f28d3753097ea9e",
	},
	{
		stock = "data/94/943d1b280637fc01",
		file = "943d1b280637fc01.livehsv",
		sha256 = "ccd40438d6778b69f25519d2597d78ffed1472bcaee077b9d66de73cdc5bd5fa",
	},
	{
		stock = "data/95/953a43ee8c53c708",
		file = "953a43ee8c53c708.livehsv",
		sha256 = "032d8d1cb599b4aa3d15b937b828cc76123c128beb0b44bb6fea23c1075ed7e6",
	},
	{
		stock = "data/ae/aeac9afc8d4df9bb",
		file = "99ff58cc04799e02.livehsv",
		sha256 = "ff37a1f97b5fe527bc936cf757f027528b5ed5df7f77d58716a842a3bd2d1ede",
	},
	{
		stock = "5dc0d564aae47b93",
		file = "5dc0d564aae47b93.pyro",
		sha256 = "470c3604d6b9db8db3f5c4571aeb1ca40aa9400c7d92815897a991108334a24d",
	},
	{
		stock = "data/70/70874be43492180f",
		file = "70874be43492180f.livehsv",
		sha256 = "35f8e92db9a6ce4c4164ccbc9d658d89aece923193ad30ab3795a7287faba4a8",
	},
	{
		stock = "data/ac/acfde9cb5522d20e",
		file = "5b86a311c0ac5cf0.livehsv",
		sha256 = "0aebeb964c5b7d10012658a336a210319e0a6762a384272129445472064b21f7",
	},
	{
		stock = "data/b6/b6fb4f31823ffdae",
		file = "2ac35fee97857b92.livehsv",
		sha256 = "4810e18dccca242d6eb319ab7ae7dc9c6db0c52296248d6fe7e9b7498e9f0343",
	},
	{
		stock = "data/09/0937ecdd02b49a51",
		file = "0937ecdd02b49a51.glowmat",
		sha256 = "59608657d9d932738eedb136213f362195721fb0ea846a1ea774e05e48ac5081",
	},
	{
		stock = "data/38/389635690311f44d",
		file = "389635690311f44d.livehsv",
		sha256 = "141a4baa5ac66884ecaa51fa23e3b1684c371fa254159b042dea261109cfee14",
	},
	{
		stock = "data/35/35978c7053a8aafc",
		file = "35978c7053a8aafc.livehsv",
		sha256 = "b20f8741c87e2b8eb472708ce4fc77df109cdbf9a4851f03139ee35a49e9e12e",
	},
	{
		stock = "data/70/707cdbdd606c30cd",
		file = "ace5d2aa548b1ba8.livehsv",
		sha256 = "547e45bbcbce33cacb12e99dbe03153031d9e0380da063af5ae934a8669d9b03",
	},
	{
		stock = "data/9b/9b10dd963027a9b2",
		file = "7082301abe176951.impactglow",
		sha256 = "746fbe232869b9c6a714350854dfb67c919fccb7a93b215471614a996ca69c54",
	},
	{
		stock = "data/4f/4f3403e5378fc65d",
		file = "4f3403e5378fc65d.parentswap",
		sha256 = "5de1cb0c229de5e9eb0280565b137996b29816b4cd3b3775327f810e9dc3a443",
	},
	{
		stock = "data/d4/d436973b399d0f0f",
		file = "af6345509d7beaa3.parentswap",
		sha256 = "64e8c4ac13eedea62c49eac8ee7c81fa990b30c85982ba20b8a72b9607091585",
	},
	{
		stock = "data/50/501fc3a18853b87e",
		file = "27c0cb428a261dc8.livehsv",
		sha256 = "7fc17b651afbd5063094cf7f13960c14318ecd8b273068bced66281aa1a8ed85",
	},
	{
		stock = "data/a0/a05cac4ba1830c52",
		file = "a05cac4ba1830c52.livehsv",
		sha256 = "963e06a9c87b66dfe3687832796db3cc8a9cd1caf1dfea1c3ac5666c2089cb90",
	},
	{
		stock = "data/b6/b674173297823523",
		file = "b674173297823523.livehsv",
		sha256 = "23ab01eef04afa80f293a5a22205872fbec737671594ba21ec4d672ecc0b1969",
	},
	{
		stock = "data/c7/c77100b7e03c017e",
		file = "c77100b7e03c017e.livehsv",
		sha256 = "9ae9d5c99d88e44d3a8e593f46a5eaa3d5248e884663d49527d90b644d209893",
	},
	{
		stock = "data/c9/c9a22ea5418d46c4",
		file = "c9a22ea5418d46c4.livehsv",
		sha256 = "7d972e76c5a118be6e353c29cab97b7711a03cdd2ed1e912b434ab7308fd832a",
	},
	{
		stock = "data/d5/d59ba29afc0927bb",
		file = "d59ba29afc0927bb.livehsv",
		sha256 = "83596cff811f1bb46b8e3230db238d6293da0502f4e116ed7ddb1964d4626bc6",
	},
	{
		stock = "data/eb/eb6d4860ae6b197a",
		file = "eb6d4860ae6b197a.livehsv",
		sha256 = "4760b81f2d90c0655d0e6f4b965a49e701ad8a3cf533f90909c9ce2f462b698e",
	},
	{
		stock = "data/ee/eed5a626643585ec",
		file = "eed5a626643585ec.livehsv",
		sha256 = "d46d3ff0e440cac95291ee2db4350cc368cb89832a845865330c1c6f8a9e3b86",
	},
	{
		stock = "data/f8/f88272fabfa9807e",
		file = "f88272fabfa9807e.livehsv",
		sha256 = "1d3f5f7cec813d6b1a16782093bc2507ee7515eea22fb7acb5450afb6b2680de",
	},
	{
		stock = "0248bd48defd788e",
		file = "0248bd48defd788e.pyro",
		sha256 = "6a1c41a456348c78039fb66bc2c5e3db4c48f6cbe80a665044ac410a5a35bf46",
	},
	{
		stock = "038a622c4f8dae2c",
		file = "038a622c4f8dae2c.pyro",
		sha256 = "e0811d0e630e3bf10e0473e6b4fb81d3544cbbad49a3d64769deb7b1b601249a",
	},
	{
		stock = "06c8bd5dcfb5e7eb",
		file = "06c8bd5dcfb5e7eb.pyro",
		sha256 = "f52c73413b211b66917bfeb9b1dd4dc20f23551235d16b749db73062df8be696",
	},
	{
		stock = "07b2d9094a94893e",
		file = "07b2d9094a94893e.pyro",
		sha256 = "997625f432f630f8c0c04f8323c2e207b3c7960bb3b9ca62d9a4abc794d3dcb4",
	},
	{
		stock = "09cba8bbfcd95fe1",
		file = "09cba8bbfcd95fe1.pyro",
		sha256 = "ecad8f8027e370d35d26e3724cafccee65ec80a778fa9e5dc4730dd85f6e3a70",
	},
	{
		stock = "0f9a5678bd0a3560",
		file = "0f9a5678bd0a3560.pyro",
		sha256 = "f1906429db4cc8409bb06c64bf2260fd25ac80d82a1fc7b5844a45a16380f3b6",
	},
	{
		stock = "14a1118d1b478a79",
		file = "14a1118d1b478a79.pyro",
		sha256 = "c9506d01c224157288dd994047e3225d02de614c9585610a76289ce25bacbe04",
	},
	{
		stock = "348d27134018dd32",
		file = "348d27134018dd32.pyro",
		sha256 = "ccfcc178c403e8449040851c36333e4819589dd49c6e0390a565bec09556f7d6",
	},
	{
		stock = "3722e7139ac94d7e",
		file = "3722e7139ac94d7e.pyro",
		sha256 = "aa89ac87aa82f294cd5582bfba96a6664df65cae90032d75cd6f5f9d2e67f55e",
	},
	{
		stock = "4a23053559b62d82",
		file = "4a23053559b62d82.pyro",
		sha256 = "f07f202c6116ead6c5279a545336387f2c2acb487b170d5b3d974731b6690944",
	},
	{
		stock = "5e2f514ce9a3a638",
		file = "5e2f514ce9a3a638.pyro",
		sha256 = "b863b16890913d01c8426240978210c430bc3e7c09dc9ee8b4e911e1558121d0",
	},
	{
		stock = "612e6312440e0738",
		file = "612e6312440e0738.pyro",
		sha256 = "81ecd03d4c37828b1389fca9a0e4a04166f224e791ff2a9401db9fbacf56e7d5",
	},
	{
		stock = "65fffac97bc7ff98",
		file = "65fffac97bc7ff98.pyro",
		sha256 = "c174e8b5658e269f3c1781329c86c1dea021ddce25f957f84704b8bea10779f7",
	},
	{
		stock = "689dc94618cb3a45",
		file = "689dc94618cb3a45.pyro",
		sha256 = "f44afa91c7154879da6702573e381a0ed0a431d195106f9743bbfae8a410f37a",
	},
	{
		stock = "76a1b3d86421bc64",
		file = "76a1b3d86421bc64.pyro",
		sha256 = "3758f36171fac9c343b4414e3c949ccee038d83ef79c8a70ba9dd68266e5ac80",
	},
	{
		stock = "9a67cf5c0db091b7",
		file = "9a67cf5c0db091b7.pyro",
		sha256 = "9eee2ef21154d52f1a8adc66dcf821eb21d382e7ff30ef70dcd44d84d7a2f84a",
	},
	{
		stock = "a4bd496cf91cd8c9",
		file = "a4bd496cf91cd8c9.pyro",
		sha256 = "5569b4e797273d0d586bb0b0fc3f55b40f3f2b1367cc04a7e668773dca9ec733",
	},
	{
		stock = "b38a462dc5c779f3",
		file = "b38a462dc5c779f3.pyro",
		sha256 = "2f64b348a8d728ee49ece6a92a843bc11454e67d12c5e7c58fcaeb7ee18bb7c8",
	},
	{
		stock = "c0c865abfb9f366a",
		file = "c0c865abfb9f366a.pyro",
		sha256 = "ce1b4a58b2477d9f841e819c6e9c3141b450d8439e0d9ad4dd259147bc1204b2",
	},
	{
		stock = "d39791625c6317ee",
		file = "d39791625c6317ee.pyro",
		sha256 = "935f5eab53f74ddb96c3e351480082ef8cc51a6454fff256aebe89ab241ce8a9",
	},
	{
		stock = "d753d8a1655a082f",
		file = "d753d8a1655a082f.pyro",
		sha256 = "ec209c6e3076e4a9e525c61264b826663d70157f1280b4b8fa9cc21f14b14f3e",
	},
	{
		stock = "e064bea4d1676af6",
		file = "e064bea4d1676af6.pyro",
		sha256 = "eda28d88c91218558b3d7950d0ba3593b9b159344bea6a4f5131cd5c2f6cf6d8",
	},
	{
		stock = "e09197022a87df08",
		file = "e09197022a87df08.pyro",
		sha256 = "781f3eb26aed06e16892f1b44fc9668b3eb6fa05cc96c59040f22b248027f93d",
	},
	{
		stock = "ec4de4ad48cd9642",
		file = "ec4de4ad48cd9642.pyro",
		sha256 = "d7eaf1aa59e8c05b3da7c41a2c3f69246c18b37bb7fe89c1273b55b9e4f4997f",
	},
	{
		stock = "f038b72029cdfd17",
		file = "f038b72029cdfd17.pyro",
		sha256 = "8cf60bc12ca8de26770d58e438581cb09f3d3d49794b846b814891eedda759d6",
	},
	{
		stock = "7ac77c633a633519",
		file = "7ac77c633a633519.pyro",
		sha256 = "de71723cacda9bb5fb4af8a6fba595584926756038266c79327183291b5d3f62",
	},
	{
		stock = "cbcca419ae0640a7",
		file = "cbcca419ae0640a7.pyro",
		sha256 = "33967ecd03d891b82265ff9c3f5a38a3ded79f9654c8524d145e426530625c9e",
	},
	{
		stock = "0b980c9f7390b814",
		file = "0b980c9f7390b814.pyro",
		sha256 = "20eef74abb7204ce19ba233ff7bad6e60e7fbe555d55b2765ac5575cbce86e54",
	},
	{
		stock = "dbd84b4615d9283f",
		file = "dbd84b4615d9283f.pyro",
		sha256 = "1a05717310f50c2781a549522d774b7e7ef43c368c141a6033b6b043f905c7c9",
	},
	{
		stock = "d74ff4b3e8e3181a",
		file = "d74ff4b3e8e3181a.pyro",
		sha256 = "1407b1fe45e907dcff1c937037d8f2c55abc612f97de8a7a03ee77092d50c93e",
	},
	{
		stock = "4a840ee5e3b66cc9",
		file = "4a840ee5e3b66cc9.pyro",
		sha256 = "43bf392bd17541882be67c9b886406a3070ffaee4be9fa7f38c438e9264d3c8c",
	},
	{
		stock = "8a9772d631c91f16",
		file = "8a9772d631c91f16.pyro",
		sha256 = "97dd4875aa928d8ee8a9a5a22b0ef168b09b41f550520ec0fe5fe709d3921a2e",
	},
	{
		stock = "68734b716177628a",
		file = "68734b716177628a.pyro",
		sha256 = "ee047b6dab8e5aa9e83058b7e0524ce8c40f95268a5ae4463acec6e87454ffa1",
	},
	{
		stock = "b2ab43e19a346c75",
		file = "b2ab43e19a346c75.pyro",
		sha256 = "b003c2ba21c558205eddbc4b5b393378b6bad44788d68a69823a10a71e5241f8",
	},
	{
		stock = "6e917a650061beaf",
		file = "6e917a650061beaf.pyro",
		sha256 = "07e08d4075c7e913c3f95ab47c314829ade330a6f6bc4f43d5743630bb18d6a8",
	},
	{
		stock = "d13e42a884c3b56f",
		file = "d13e42a884c3b56f.pyro",
		sha256 = "cde42f23ef68bdcf76c10b6b9e70f85e2532e4c7e6f6f92206a2eeaf2279d1f6",
	},
	{
		stock = "1d0a330580de1af7",
		file = "1d0a330580de1af7.pyro",
		sha256 = "75e01dfc6c53af6bed5437a5b04383f1a19f7ac4e7ecb835d01e2d8348ca69db",
	},
	{
		stock = "3df8ad0d3d73a028",
		file = "3df8ad0d3d73a028.pyro",
		sha256 = "8d32fc7e651bf18be99a04488c72a0f310d86697fa66108547890d9a11dbc4be",
	},
	{
		stock = "23c0862fe51e5d60",
		file = "23c0862fe51e5d60.pyro",
		sha256 = "d39bdce5d5e67b91cd3b600b4eef1ea229bb9989e48381524986e4309e1f01eb",
	},
	{
		stock = "18b0e90067703071",
		file = "18b0e90067703071.pyro",
		sha256 = "05ea2a25a73ff1712451ad6a557c2e33277fbfeea3b8bae1c963e297aee98270",
	},
	{
		stock = "b2cf6dbdf08bd3d1",
		file = "b2cf6dbdf08bd3d1.pyro",
		sha256 = "f4d06cacfffbd9cc5dac590a5f69aeedd51f3c83f819c569d9e04e6e3cde7fe5",
	},
	{
		stock = "3bd9a0bec62e6482",
		file = "3bd9a0bec62e6482.pyro",
		sha256 = "0f86f4eec29512123532b6d3d0b845ad119ede9f290a223944eafd75b071f1ae",
	},
	{
		stock = "e0494ef57fa94662",
		file = "e0494ef57fa94662.pyro",
		sha256 = "66cfe6a91e7fb802cd9222b6049ae112353871996aaaf85a219d713e8b69b336",
	},
	{
		stock = "c20b89050d9fa253",
		file = "c20b89050d9fa253.pyro",
		sha256 = "d8d9c432e80699cc972c6f910d821c186830336a4dcc5bfe2ad05597aab991b3",
	},
	{
		stock = "b05407e4d7524dca",
		file = "b05407e4d7524dca.pyro",
		sha256 = "bc992cbeb1f8802839e175f2abbc6335c321c82bab955c9494c8dc2bef316bdf",
	},
	{
		stock = "data/96/9620f9e397e4fda4",
		file = "9620f9e397e4fda4.livehsv",
		sha256 = "b497b57410e3bef275b65d84122d8f14108ee5fb6410e4d4d44700efb5c88a52",
	},
	{
		stock = "data/b5/b568acd1f3be5206",
		file = "b568acd1f3be5206.livehsv",
		sha256 = "e04e5b9c9e913df69fb111654b9fb451fb8aa45e8febfc43d511ae42b847939d",
	},
	{
		stock = "data/2e/2e84f67cb43e161e",
		file = "2e84f67cb43e161e.livehsv",
		sha256 = "2380c3154317e1814624d41dfd907172b61bfc84281c0f07feb32345ed7ab3ec",
	},
	{
		stock = "data/9c/9c6892714be719be",
		file = "9c6892714be719be.livehsv",
		sha256 = "e95f126ac4034bd736eea45c860c162e059ddb748e3629100f649e98eec4ae09",
	},
	{
		stock = "data/73/731949c698805166",
		file = "731949c698805166.livehsv",
		sha256 = "e55f03ef392281aec940e6fc848e541999ab2b7eec3a50f4a49e85cc31fa46be",
	},
	{
		stock = "data/e6/e698932c695e72d7",
		file = "e698932c695e72d7.livehsv",
		sha256 = "857f110f76119803cdd974ab380343474ed4c8301d721fc6e27d553a1c27b02d",
	},
	{
		stock = "data/5f/5f599134bd6cb4d7",
		file = "5f599134bd6cb4d7.livehsv",
		sha256 = "b7af5f9bf5296ed5bc847cabd1800e6f22d7f2f842f0bc9e101e7d91ab73474a",
	},
	{
		stock = "data/18/18c49d3c8a5beffb",
		file = "18c49d3c8a5beffb.livehsv",
		sha256 = "4e37d9e2cc997bb09a66d44e715fb75ca4981f9c5a6779a1a8ca2bfd19699256",
	},
	{
		stock = "data/b3/b3b02753bc5c5eb6",
		file = "b3b02753bc5c5eb6.livehsv",
		sha256 = "4e547733db2b26e9741c4501792d622d612c0028d80ad3348b838fbdbcba8bde",
	},
	{
		stock = "data/90/908e498779039c2f",
		file = "908e498779039c2f.livehsv",
		sha256 = "8492fa5d766ef9e01fbae0a9cf59440ccdecfcdbd3758c8f2ed4e79c2ed4ed2c",
	},
	{
		stock = "data/3d/3d61898424cd2d53",
		file = "3d61898424cd2d53.livehsv",
		sha256 = "4875651662fd6972b82dbebb2a6ac3ac65343d501eec678d57b2a19f9036d168",
	},
	{
		stock = "data/71/71c11a9ab38ccef6",
		file = "71c11a9ab38ccef6.livehsv",
		sha256 = "6d1674bcd5478d3acf1456ed4d960b4970fb83d8769d4c04bf2ba1de8f4fcec2",
	},
	{
		stock = "data/d4/d44c3e55524792c0",
		file = "d44c3e55524792c0.livehsv",
		sha256 = "c122610c5dd94867abb7f3431f61c169156881f6305e4e05b72502c930d4a4f0",
	},
	{
		stock = "data/2c/2cf5a90222f0f675",
		file = "2cf5a90222f0f675.livehsv",
		sha256 = "b596193206f907a928c0628a4f90800d21f7e947706187b4c8e109cbd38922d9",
	},
	{
		stock = "data/ed/edd0c83a7ed3d834",
		file = "edd0c83a7ed3d834.livehsv",
		sha256 = "87cc14d6afc300596c19a501395b5366a7a47ff7c9a71928d1ab9ad01ef2c382",
	},
	{
		stock = "data/51/51594febc2f498b9",
		file = "51594febc2f498b9.livehsv",
		sha256 = "74f52a0637ba53fa7a46663ba4860c7eef81d30236ec790667a81333e878b4ec",
	},
	{
		stock = "data/51/51be2b7e18d16f85",
		file = "51be2b7e18d16f85.livehsv",
		sha256 = "a10864140669930a89015ff4cf451ed7afe46cd9fbc25fa9a76b0b142fdf841d",
	},
	{
		stock = "data/96/9648f7e733af27de",
		file = "9648f7e733af27de.livehsv",
		sha256 = "214dcff839537336121802c3bbb2e866650039b9c6768db0dc0ddcd2983bf10a",
	},
	{
		stock = "data/1b/1b59d000e1b00a00",
		file = "1b59d000e1b00a00.livehsv",
		sha256 = "d8c56b2940d70eb53b23243560054cf5edc559cc0ad6455f6b158547c88923ab",
	},
	{
		stock = "data/7b/7b5f45d570446038",
		file = "7b5f45d570446038.livehsv",
		sha256 = "1b995662d3f11249cf2199efd343fdb2b114259c7d286345aba090d65c6ea537",
	},
	{
		stock = "data/3e/3e7d35923677ce5b",
		file = "3e7d35923677ce5b.livehsv",
		sha256 = "254bd2200f27c4db955b0baecdade15601e253cf0d9080b1d9d5fad792ea6134",
	},
	{
		stock = "data/c2/c29d268a1116d6c8",
		file = "c29d268a1116d6c8.livehsv",
		sha256 = "d544156b87acdf683d6a90c26448cc325d27693ed4fc301aef5ae12149b4aa97",
	},
	{
		stock = "data/33/3336d5d7ab5ea336",
		file = "3336d5d7ab5ea336.livehsv",
		sha256 = "2d8a4ab46252c021034cb158fcd89cf60b0b1437bbc4055284611ff72ae59bc2",
	},
	{
		stock = "data/bf/bf4522e91fe81307",
		file = "bf4522e91fe81307.livehsv",
		sha256 = "ffc8d04018f6d0fd694e6da7f92c336df9db7f3181f6dc6ea2fb6df2b5483856",
	},
	{
		stock = "data/94/947f9d05243c5c05",
		file = "947f9d05243c5c05.livehsv",
		sha256 = "ef67837e14663e0e8703158441fe80682237ba9895f7bd27e06f694474ac3008",
	},
	{
		stock = "data/e2/e28e22d29032ef7f",
		file = "e28e22d29032ef7f.livehsv",
		sha256 = "a8622ac9082fd5f1c5b3b714ccffc13330d49de71bbc74da988dcd123e751e00",
	},
	{
		stock = "data/23/23fef9dc3db476e5",
		file = "23fef9dc3db476e5.livehsv",
		sha256 = "4a2d5af10dbd1b310a7c24d36be5551bc14ce0f74f7f73204654d07919ba3f12",
	},
	{
		stock = "data/5b/5bb5ef9851943876",
		file = "5bb5ef9851943876.livehsv",
		sha256 = "011bdfd2b865cd203f233aa3b6dfa4508e7b08fd1eae4b1e9a326f66e25d7ce4",
	},
	{
		stock = "fa1369b4111125f6",
		file = "fa1369b4111125f6.pyro",
		sha256 = "bfe6008ca2def239daef04f5ff8d50a4f1edd94a80f7de0ea4730a88cda065f6",
	},
	{
		stock = "712ddadee8da9e71",
		file = "712ddadee8da9e71.pyro",
		sha256 = "d79467291466d80ecbe79aa2bc9be914c0eeebd9f4a3784ea076b48bc4c557a9",
	},
	{
		stock = "data/d5/d5a0f8e3403b60c8",
		file = "d5a0f8e3403b60c8.livehsv",
		sha256 = "15151a08f681baf9bc7a01948a992268d413b5a82f106ab25bd632d2d2b4288e",
	},
	{
		stock = "data/3c/3c2bb28d1f2b943b",
		file = "3c2bb28d1f2b943b.livehsv",
		sha256 = "cb1012442c5a7e1c9c28d23139db14262cb1a3620173f2a1a0f3ba6ade2a1ae7",
	},
	{
		stock = "data/zz/f0f3000000000a00",
		file = "f0f3000000000a00.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a01",
		file = "f0f3000000000a01.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a02",
		file = "f0f3000000000a02.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a03",
		file = "f0f3000000000a03.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a04",
		file = "f0f3000000000a04.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a05",
		file = "f0f3000000000a05.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a06",
		file = "f0f3000000000a06.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a07",
		file = "f0f3000000000a07.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a08",
		file = "f0f3000000000a08.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a09",
		file = "f0f3000000000a09.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a0a",
		file = "f0f3000000000a0a.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f3000000000a0b",
		file = "f0f3000000000a0b.arcpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f0000000000901",
		file = "f0f0000000000901.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f0000000000902",
		file = "f0f0000000000902.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f0000000000903",
		file = "f0f0000000000903.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f0000000000904",
		file = "f0f0000000000904.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f0000000000905",
		file = "f0f0000000000905.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f0000000000906",
		file = "f0f0000000000906.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f0000000000907",
		file = "f0f0000000000907.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f0000000000908",
		file = "f0f0000000000908.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f0000000000909",
		file = "f0f0000000000909.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f000000000090a",
		file = "f0f000000000090a.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f000000000090b",
		file = "f0f000000000090b.plasmapal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f000000000090c",
		file = "f0f000000000090c.plasmapal",
		virtual = true,
	},
	{
		stock = "data/f7/f7b45efae8760175",
		file = "f7b45efae8760175.livehsv",
		sha256 = "c12e67e152f9b44fe23eae6abb423229de3f938679844542f78c14b653b8dfb1",
	},
	{
		stock = "data/cb/cb1759794495e9e3",
		file = "cb1759794495e9e3.livehsv",
		sha256 = "022c7b011e28c9d5d752d03312afdfa1f77c79fa646e3386c5ec08b741f4de19",
	},
	{
		stock = "7050bcf7efa8671b",
		file = "7050bcf7efa8671b.pyro",
		sha256 = "b1c134fd979bd5515bcbf7a4d10492982912e2b8bc7a02768d0142c2cad5698d",
	},
	{
		stock = "d76e1f3df866da96",
		file = "d76e1f3df866da96.pyro",
		sha256 = "dfd617d222dd459ce551202d9bcc4cabfcb123a1b38113a8dbfcdfd08d776228",
	},
	{
		stock = "a2bdefafc2bcdcf1",
		file = "a2bdefafc2bcdcf1.pyro",
		sha256 = "3716f666e997cc145b43c8059c819cfb968a12f11d71bb664f72065df3c32f8e",
	},
	{
		stock = "e087d3f671d18d4b",
		file = "e087d3f671d18d4b.pyro",
		sha256 = "3af3639fb78bc362b9f7b100bd76ef2b107807471c7b4191693a172a18aa2d50",
	},
	{
		stock = "4e42dd58680c64de",
		file = "4e42dd58680c64de.pyro",
		sha256 = "baab403d7b284a0e059aa96c2e4f61265b55012770bbe3d51d47a2d33d0a517b",
	},
	{
		stock = "37228ce95751e97f",
		file = "37228ce95751e97f.pyro",
		sha256 = "24a90ca0387fe6435bb6157bfccaa6e0cf41a57bfa9dcaeb42dc5e926d2a5d98",
	},
	{
		stock = "1c71e8423c8828aa",
		file = "1c71e8423c8828aa.pyro",
		sha256 = "256deb9ece920dd6a92ef1bf1ecbc164e951ecba4a728aa8f28dd11bfe2422e7",
	},
	{
		stock = "aa837464aa236cfb",
		file = "aa837464aa236cfb.pyro",
		sha256 = "d559230c154d6164057f756a92dbead4d0aeddf2ca5b9acf9a5fcd0aac950eae",
	},
	{
		stock = "378a7ee55471a095",
		file = "378a7ee55471a095.pyro",
		sha256 = "c64db1c5aa217c0db025ab86e8cba3432927269a5c9ea692d2f95e7b7ddc0f08",
	},
	{
		stock = "43d4cd19046f940a",
		file = "43d4cd19046f940a.pyro",
		sha256 = "17e98b3e61d262091a94b5e794c77a498d90261b19d42d9a1cea7178b6ae6f98",
	},
	{
		stock = "2257b8606809faeb",
		file = "2257b8606809faeb.pyro",
		sha256 = "52ac3be6e53ce20aeaf30f60d7de2e7ae28fd42c77d2a3c08d3585c67c478dd0",
	},
	{
		stock = "data/3c/3ca6a9ce11c7dfe1",
		file = "3ca6a9ce11c7dfe1.livehsv",
		sha256 = "9830f634355d4a20e17553c39ed1329051615162d50817034be94508311de600",
	},
	{
		stock = "data/60/607dbb4a57138f8d",
		file = "607dbb4a57138f8d.livehsv",
		sha256 = "fd3e2a4e735e6adf4c2f73a12eacb187983154ace6414b316fb375c8b0e0581d",
	},
	{
		stock = "data/3d/3d0cb1d8ae277e71",
		file = "3d0cb1d8ae277e71.livehsv",
		sha256 = "33d0be88ab9d3e34ef72ef0d6da13c6b0ea77f585f1df32c098a1894375ecc14",
	},
	{
		stock = "data/2c/2c867be4918ccc18",
		file = "2c867be4918ccc18.livehsv",
		sha256 = "3ba9339b0a0d7aaa39d1ab41f3cc6ce60bb0dcf93a303526cd4827f1d7f3565b",
	},
	{
		stock = "data/18/18f92705d5855677",
		file = "18f92705d5855677.livehsv",
		sha256 = "b21bb799a3ada84c8b443c486665543bbbbdff9444dabd1f389ab084f2de630d",
	},
	{
		stock = "f6f1954051323147",
		file = "f6f1954051323147.pyro",
		sha256 = "7747ee618527b8dfa0790ca5905281b49ec0353c7b222e210932166a799930a6",
	},
	{
		stock = "f9a026d45df7bcea",
		file = "f9a026d45df7bcea.pyro",
		sha256 = "a884a13cb6828a6b45df246442149700becea9845e5d0a48930b929b3d5c5cbd",
	},
}

for i = 1, #LAS_REDIRECTS do
	REDIRECTS[#REDIRECTS + 1] = LAS_REDIRECTS[i]
end

local SNIPER_FLASH_REDIRECTS = {
	{
		stock = "4cc74ef319030258",
		file = "4cc74ef319030258.pyro",
		sha256 = "0c3715740bc3c3c00213bf37ad155fd79d675222db34e1aa35519c9119d7368c",
	},
	{
		stock = "cadc4aad69c172b6",
		file = "cadc4aad69c172b6.pyro",
		sha256 = "2ff8f632ee2e3dafeb584e627335d6039093ce4d309fce08f22cb87c0e31d340",
	},
	{
		stock = "4a5ab95b41bb65a4",
		file = "4a5ab95b41bb65a4.pyro",
		sha256 = "88760b6da1d1dc31ad76a3ddf9fdc7184647f8c7c602be03ba761fdfbe9a89ff",
	},
}

for i = 1, #SNIPER_FLASH_REDIRECTS do
	REDIRECTS[#REDIRECTS + 1] = SNIPER_FLASH_REDIRECTS[i]
end

local BURN_REDIRECTS = {
	{
		stock = "data/b2/b250a66edd2382b7",
		file = "b250a66edd2382b7.burnhsv",
		sha256 = "b245262d4f3f4778fd87f42ac33e08355487359131a87154525e6e907ce9a173",
	},
	{
		stock = "data/4f/4f3c20108df32ff2",
		file = "4f3c20108df32ff2.burnhsv",
		sha256 = "1a04fc2d6fed9082916aa63ae13d7708b42367dda9aa27f7b842348e7e4325f1",
	},
	{
		stock = "data/ad/ade3d7d830f2254a",
		file = "ade3d7d830f2254a.burnhsv",
		sha256 = "f2090cf4c2692c50d108246dd427f027573f3e6b5e93fb2a41bfdf5a20129e4a",
	},
	{
		stock = "data/eb/eb09dd77efe06a9d",
		file = "eb09dd77efe06a9d.burnhsv",
		sha256 = "8b7ff871f4aedbad4d95e75885302cf0abd1fc8c05845b8d7899339bb8bfd688",
	},
	{
		stock = "data/2d/2d197c488c9bebc2",
		file = "2d197c488c9bebc2.burnhsv",
		sha256 = "708624b602f9afd4713cfb6db6de07d3177a9f07634e34f2555d3a9940e46d5c",
	},
	{
		stock = "data/35/35ef09cd5356eead",
		file = "35ef09cd5356eead.burnhsv",
		sha256 = "98313507ea71ac15c50c18e3d798e1d2f4a55d89c46396df832e82324381df14",
	},
	{
		stock = "data/7f/7f17d42421a43450",
		file = "7f17d42421a43450.burnhsv",
		sha256 = "2ee0dedaae49293f3cbc76ea463b334236c230e2d14d07e5d3c3e066c1f62313",
	},
	{
		stock = "data/44/4490a3f7f03c1e69",
		file = "4490a3f7f03c1e69.burnhsv",
		sha256 = "8ee1886f3953e8c772f8b99f7b33d5e3d0c3168ba5dab8a98e3d8c67d11fb0db",
	},
}

for i = 1, #BURN_REDIRECTS do
	REDIRECTS[#REDIRECTS + 1] = BURN_REDIRECTS[i]
end

local MIN_BRIGHTNESS_STEP = 1
local STOCK_BRIGHTNESS_STEP = 8
local MAX_BRIGHTNESS_STEP = 15

local function redirect_served(state)
	return state == "active" or state == "shared" or state == "compatible"
end

local SOUL_SLOTS = {
	{
		package = "content/fx/particles/debug/fx_debug_gpu_fireball",
		bundle = "2e65e32cf980553b",
		bundle_sha256 = "c7f632d222cb1dacc1c4936497a6b12d47ffb42752c99300c753d944fe7c9c7b",
		material = "data/3f/3ffd686f6ff27952",
		material_sha256 = "87ca4f1559557d2720059fea1daffb191b4fb45d8de61769677f417bc1df0feb",
	},
	{
		package = "content/fx/particles/debug/fx_debug_gpu_fireball_normal",
		bundle = "f0806ea958cf8ff7",
		bundle_sha256 = "1b1ff8645e7927d065b3a35417bb674bd55514746bdb58e5e3615bdfa4738a9d",
		material = "data/da/dacf0e63f7921f7a",
		material_sha256 = "94b59b82660b3782f28c0e7fea89885a6aa047fc9190b9d1b7e43da6dbe430bf",
	},
	{
		package = "content/fx/particles/weapons/rifles/ripper_gun/ripper_gun_trail",
		bundle = "2e58389b6ed2142d",
		bundle_sha256 = "5012fb3008acb1f00827c9aeb76463280d5fb1d99b2f013e485936d458d079ce",
		material = "data/3c/3c50f2ff573a08cd",
		material_sha256 = "d0aef3b35dcdce97857fe9df44451a840d1471740384bcf431f837b3d1975450",
	},
	{
		package = "content/fx/particles/impacts/weapons/hammer_impact",
		bundle = "14d5b2c5e9ebee8f",
		bundle_sha256 = "8eddf55f76cd34d5b88b3b44c7e5400a7a58d97464e1ba829183f1852333ba10",
		material = "data/fd/fdf161cab348d473",
		material_sha256 = "7f029e9d7df99b71986066480350cc2c69cb722131a51a187fba9375b29a0fb7",
	},
	{
		package = "content/fx/particles/enemies/plague_ogryn_flies",
		bundle = "f608745eeef0699e",
		bundle_sha256 = "f7f5be2a1a0babc98eea173b7b8e59b1698f54405de9a1fc6e50788071634290",
		material = "data/05/0513e621cdd87ad5",
		material_sha256 = "d448c8383e4553409ea313163e1c93ccadb16cd7c2fcea96c1b68b653a8206a3",
	},
	{
		package = "content/fx/particles/enemies/lasgun_beam_assault",
		bundle = "d1b72a7d311e7090",
		bundle_sha256 = "63c42459f77dafa516c7ddc15eb6223b617b7147ab110ee1a2fdc180d97fdfd4",
		material = "data/1a/1a07775aebe7ef0e",
		material_sha256 = "b6901364f4565352241d8287d7dad2c46b4f8f11dd5e0afd97fb55fe629fd063",
	},
	{
		package = "content/fx/particles/liquid_area/corruptor_nurgle_goo_splatter",
		bundle = "e0f0480393b4255a",
		bundle_sha256 = "674e0bcb8b1b9c25f5aae9c38add454ac7e4600d16ed68dace2d1c8472f50e0d",
		material = "data/f1/f197c21689ca1ef6",
		material_sha256 = "56aa80e289f0518e9557b9b35e70bbaade02cafe222c514c8187bca1de86b6e6",
	},
	{
		package = "content/fx/particles/weapons/rifles/shotgun/combat_shotgun_ogryn_impact_v01",
		bundle = "9d3c4c3582f50f13",
		bundle_sha256 = "9d14be1f9cea237647e375e0847d0089ef1aa9b9beffd358c1a73da5c5153f89",
		material = "data/87/87df9553641534df",
		material_sha256 = "bfaf1600e14c39f6b213618faff0a088fa098b43439605f317e0870474b5a0cd",
	},
	{
		package = "content/fx/particles/screenspace/screen_ogryn_charge",
		bundle = "80d83c7c23a3464b",
		bundle_sha256 = "6764699f2c10ecdc0930ddd4a926173432215c102778f761a05af9016aa7d14a",
		material = "data/21/21e06c09435b212e",
		material_sha256 = "b1f72270e3420aac7c4ea66c99d87bcb014a3e5b5303e339e24764849b0c9e8c",
	},
	{
		package = "content/fx/particles/weapons/rifles/zealot_flamer/zealot_flamer_code_control",
		bundle = "4713ab38f46f4f07",
		bundle_sha256 = "3cdc22e667dc8c53a3982c97c105fd69b333f081efa8b7d71e1e58618b4dcc35",
		material = "data/3e/3ecd3bb2d511984e",
		material_sha256 = "f4e9ee33c27fdff596f2641d7ddefbb940a04a6ac73175cdf4f8c76b7a7e2900",
	},
	{
		package = "content/fx/particles/impacts/weapons/lasgun/lasgun_impact_weakspot",
		bundle = "e3eac989dc018e47",
		bundle_sha256 = "58225a9e98b515a7095908ac811be8d7621f8ea9f7fe8b296fe3637548145e9f",
		material = "data/17/170af2d8a7f30f7b",
		material_sha256 = "565095500e790db9431943162dc19cc6b5ff7e757e1625f53cfa55584fc73917",
	},
	{
		package = "content/fx/particles/screenspace/screen_zealot_preacher_shield",
		bundle = "84d9e75472d57ebb",
		bundle_sha256 = "4f7a6192442e98fa9572411d158b77d09f7e5f85ca0b4f4531c4b3cf1b8417ca",
		material = "data/75/750c5672dc47d156",
		material_sha256 = "3cd5dd804fb51e63ead0bf3cd48dcabd99a5357e21cf17de69ef7d87accbfb1f",
	},
}
local SOUL_PAYLOAD_DIR = "../mods/Polychromatic/payload/"
local SOUL_TEMPLATE_FILE = "soulblaze_flame.template"
local SOUL_TEMPLATE_SIZE = 244
local SOUL_VALUE_OFFSET = 220
local SOUL_HUE_STEPS = 1024
local SOUL_SATURATION_STEPS = 15
local BURN_LAYERS = {
	{ template = "burn_0.burntemplate", size = 244, offset = 220 },
	{ template = "burn_1.burntemplate", size = 312, offset = 272 },
	{ template = "burn_2.burntemplate", size = 508, offset = 460 },
}
local BURN_PALETTE_SLOTS = 12

local function burn_material_file(layer, slot)
	return string.format("burn_%d_%02d.burnmat", layer - 1, slot - 1)
end

local function burn_material_loose(layer, slot)
	return string.format("data/zz/f0f5000000001%x%02x", layer - 1, slot - 1)
end

local function soul_material_file(slot)
	return string.sub(slot.material, 9) .. ".soulmat"
end

local function soul_bake_profile()
	for _, category in ipairs({ "mine", "team" }) do
		local prefix = "staff_" .. category .. "_"
		local mode = mod:get(prefix .. "mode") or "stock"

		if mod:get(prefix .. "show") ~= false and mode ~= "stock" then
			local saturation = 1
			local colour = mod:get(prefix .. "colour")

			if mode ~= "rainbow" and type(colour) == "table" then
				local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
				local high = math_max(r, g, b)

				saturation = high > 0 and (high - math_min(r, g, b)) / high or 0
			end

			return saturation, mod:get(prefix .. "brightness") or STOCK_BRIGHTNESS_STEP
		end
	end

	return 1, STOCK_BRIGHTNESS_STEP
end

local GLOW_TEMPLATE_FILE = "0937ecdd02b49a51.glowtemplate"
local GLOW_MATERIAL_FILE = "0937ecdd02b49a51.glowmat"
local GLOW_TEMPLATE_SIZE = 308
local GLOW_VALUE_OFFSET = 264

local IMPACT_GLOW_TEMPLATE_FILE = "7082301abe176951.impactglowtemplate"
local IMPACT_GLOW_FILE = "7082301abe176951.impactglow"
local IMPACT_GLOW_SIZE = 371985
local IMPACT_GLOW_OFFSET = 244

local function bake_impact_glow()
	local lua = rawget(_G, "Mods") and Mods.lua
	local ffi = lua and lua.ffi
	local lua_io = lua and lua.io

	if not ffi or not lua_io then
		return
	end

	local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. IMPACT_GLOW_TEMPLATE_FILE, "rb")

	if not template_file then
		mod:info("las impact glow: template missing, shipped default used")

		return
	end

	local template = template_file:read("*a")

	template_file:close()

	if not template or #template ~= IMPACT_GLOW_SIZE then
		return
	end

	local value = ffi.new("float[1]", 1000)
	local mode = mod:get("las_mine_mode")

	if mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow") then
		local brightness = math_max(1, math_min(15, mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP))
		local hue, saturation = 0, 0

		if mode == "custom" then
			local colour = mod:get("las_mine_colour")

			if type(colour) == "table" then
				local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
				local high, low = math_max(r, g, b), math_min(r, g, b)

				saturation = high > 0 and (high - low) / high or 0

				if high > low then
					if high == r then
						hue = ((g - b) / (high - low)) / 6
					elseif high == g then
						hue = (2 + (b - r) / (high - low)) / 6
					else
						hue = (4 + (r - g) / (high - low)) / 6
					end

					hue = hue - math_floor(hue)
				end
			end
		end

		local hue_step = math_floor(hue * 1024) % 1024
		local saturation_step = math_floor(saturation * 15 + 0.5)

		value[0] = 1000 + saturation_step + (hue_step * 16 + brightness) / 16384
	end

	local bytes = string.sub(template, 1, IMPACT_GLOW_OFFSET) .. ffi.string(value, 4) .. string.sub(template, IMPACT_GLOW_OFFSET + 5)
	local path = SOUL_PAYLOAD_DIR .. IMPACT_GLOW_FILE
	local existing = lua_io.open(path, "rb")
	local current = existing and existing:read("*a")

	if existing then
		existing:close()
	end

	if current ~= bytes then
		local out = lua_io.open(path, "wb")

		if out then
			out:write(bytes)
			out:close()
		else
			mod:info("las impact glow: cannot write %s, shipped default used", path)
		end
	end
end

local GLOW_SLOTS = {
	muzzle = {
		{
			package = "content/fx/particles/debug/fx_debug_1m_blue",
			bundle = "6c363592a35f5599",
			bundle_sha256 = "8ab4b5e21781b700051df420a400b0f3ae028ca7d272640eb38571936f405c4f",
			material = "f0f0000000000007",
			virtual_path = "data/zz/f0f0000000000007",
		},
		{
			package = "content/fx/particles/debug/fx_debug_1m_red",
			bundle = "88cedce8a498f97e",
			bundle_sha256 = "4dea34a5d7d323d046af778991c008e2352982a0d2b8106cf1860566d8bc0f96",
			material = "f0f0000000000008",
			virtual_path = "data/zz/f0f0000000000008",
		},
		{
			package = "content/fx/particles/debug/fx_debug_1m_green",
			bundle = "d932eac771ff85ae",
			bundle_sha256 = "38d3c5c84bab2547f5ecd0c17d2f0658295f4ffd137b2a828a149404d58ee782",
			material = "f0f0000000000009",
			virtual_path = "data/zz/f0f0000000000009",
		},
		{
			package = "content/fx/particles/impacts/flesh/blood_splatter_01_old",
			bundle = "81686d16269ea030",
			bundle_sha256 = "89d512bf2f590d966944fa3cd71d3ce262f7ac8aad3b9e789f46731cd29c8cd1",
			material = "f0f000000000000a",
			virtual_path = "data/zz/f0f000000000000a",
		},
		{
			package = "content/fx/particles/impacts/flesh/blood_fountain_head_01_old",
			bundle = "43fcfaba468316d8",
			bundle_sha256 = "8a0c6162946fcb7e99f43ccecac541773b9ace84973ce0fea77c3d3271426e1b",
			material = "f0f000000000000b",
			virtual_path = "data/zz/f0f000000000000b",
		},
		{
			package = "content/fx/particles/impacts/weapons/autogun/autogun_impact_02_old",
			bundle = "ff966c81581e8207",
			bundle_sha256 = "0146e4e7e09303bdcafaf56305ba6dcdb64328fa826432ddc64bea2520524998",
			material = "f0f000000000000c",
			virtual_path = "data/zz/f0f000000000000c",
		},
	},
}

local GLOW_SOURCE_EFFECTS = {
	["content/fx/particles/weapons/rifles/laspistol/laspistol_heavy_muzzle"] = "muzzle",
}
local GLOW_IMPACT_TEMPLATE = "7082301abe176951.impactglowtemplate"
local GLOW_MUZZLE_TEMPLATE = "0937ecdd02b49a51.glowtemplate"
local GLOW_IMPACT_SIZE, GLOW_IMPACT_OFFSET = 371985, 244
local GLOW_MUZZLE_SIZE, GLOW_MUZZLE_OFFSET = 308, 264

local function glow_hsv_rgb(h, s, v)
	local i = math_floor(h * 6) % 6
	local f = h * 6 - math_floor(h * 6)
	local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))

	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	end

	return v, p, q
end

local function glow_hue_of(list, index)
	return (index - 1) / #list
end

local function bake_glow_palette()
	local lua = rawget(_G, "Mods") and Mods.lua
	local ffi = lua and lua.ffi
	local lua_io = lua and lua.io

	if not ffi or not lua_io then
		return
	end

	local mode = mod:get("las_mine_mode")
	local shown = mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow")
	local brightness = math_max(1, math_min(15, mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP))
	local saturation_step = 15

	if mode == "custom" then
		local colour = mod:get("las_mine_colour")

		if type(colour) == "table" then
			local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
			local high, low = math_max(r, g, b), math_min(r, g, b)

			saturation_step = math_floor((high > 0 and (high - low) / high or 0) * 15 + 0.5)
		end
	end

	for layer, list in pairs(GLOW_SLOTS) do
		local template_name = layer == "impact" and GLOW_IMPACT_TEMPLATE or GLOW_MUZZLE_TEMPLATE
		local size = layer == "impact" and GLOW_IMPACT_SIZE or GLOW_MUZZLE_SIZE
		local offset = layer == "impact" and GLOW_IMPACT_OFFSET or GLOW_MUZZLE_OFFSET
		local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. template_name, "rb")
		local template = template_file and template_file:read("*a")

		if template_file then
			template_file:close()
		end

		if template and #template == size then
			for i = 1, #list do
				local hue = glow_hue_of(list, i)
				local patch

				if not shown then
					patch = nil
				elseif layer == "impact" then
					local value = ffi.new("float[1]")

					value[0] = 1000 + saturation_step + (math_floor(hue * 1024) % 1024 * 16 + brightness) / 16384
					patch = ffi.string(value, 4)
				else
					local r, g, b = glow_hsv_rgb(hue, saturation_step / 15, brightness / STOCK_BRIGHTNESS_STEP)
					local rgb = ffi.new("float[3]", r, g, b)

					patch = ffi.string(rgb, 12)
				end

				local bytes = template

				if patch then
					bytes = string.sub(template, 1, offset) .. patch .. string.sub(template, offset + #patch + 1)
				end

				local path = SOUL_PAYLOAD_DIR .. list[i].material .. ".glowpal"
				local existing = lua_io.open(path, "rb")
				local current = existing and existing:read("*a")

				if existing then
					existing:close()
				end

				if current ~= bytes then
					local out = lua_io.open(path, "wb")

					if out then
						out:write(bytes)
						out:close()
					else
						mod:info("las glow palette: cannot write %s", path)
					end
				end
			end
		end
	end
end

local SURFACE_BAKED = {
	{ template = "f0f0000000000101.surftemplate", file = "f0f0000000000101.glowpal", size = 388884, offset = 244 },
	{ template = "f0f0000000000102.surftemplate", file = "f0f0000000000102.glowpal", size = 372033, offset = 244 },
}

local function bake_surface_glow()
	local lua = rawget(_G, "Mods") and Mods.lua
	local ffi = lua and lua.ffi
	local lua_io = lua and lua.io

	if not ffi or not lua_io then
		return
	end

	local mode = mod:get("las_mine_mode")
	local shown = mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow")
	local brightness = math_max(1, math_min(15, mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP))
	local hue, saturation_step = 0, 0

	if mode == "custom" then
		local colour = mod:get("las_mine_colour")

		if type(colour) == "table" then
			local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
			local high, low = math_max(r, g, b), math_min(r, g, b)

			saturation_step = math_floor((high > 0 and (high - low) / high or 0) * 15 + 0.5)

			if high > low then
				if high == r then
					hue = ((g - b) / (high - low)) / 6
				elseif high == g then
					hue = (2 + (b - r) / (high - low)) / 6
				else
					hue = (4 + (r - g) / (high - low)) / 6
				end

				hue = hue - math_floor(hue)
			end
		end
	end

	local value = ffi.new("float[1]", 1000)

	if shown then
		value[0] = 1000 + saturation_step + (math_floor(hue * 1024) % 1024 * 16 + brightness) / 16384
	end

	for i = 1, #SURFACE_BAKED do
		local entry = SURFACE_BAKED[i]
		local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. entry.template, "rb")
		local template = template_file and template_file:read("*a")

		if template_file then
			template_file:close()
		end

		if template and #template == entry.size then
			local bytes = string.sub(template, 1, entry.offset) .. ffi.string(value, 4) .. string.sub(template, entry.offset + 5)
			local path = SOUL_PAYLOAD_DIR .. entry.file
			local existing = lua_io.open(path, "rb")
			local current = existing and existing:read("*a")

			if existing then
				existing:close()
			end

			if current ~= bytes then
				local out = lua_io.open(path, "wb")

				if out then
					out:write(bytes)
					out:close()
				else
					mod:info("las surface glow: cannot write %s", path)
				end
			end
		end
	end
end

local function bake_glow_material()
	local lua = rawget(_G, "Mods") and Mods.lua
	local ffi = lua and lua.ffi
	local lua_io = lua and lua.io

	if not ffi or not lua_io then
		return
	end

	local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. GLOW_TEMPLATE_FILE, "rb")

	if not template_file then
		mod:info("las glow colour: template missing, shipped default used")

		return
	end

	local template = template_file:read("*a")

	template_file:close()

	if not template or #template ~= GLOW_TEMPLATE_SIZE then
		return
	end

	local bytes = template

	local mode = mod:get("las_mine_mode")

	if mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow") then
		local colour = mod:get("las_mine_colour")
		local scale = (mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP) / STOCK_BRIGHTNESS_STEP
		local rgb = ffi.new("float[3]")

		for i = 1, 3 do
			local channel = mode == "rainbow" and 255 or (type(colour) == "table" and colour[i + 1] or 255)

			rgb[i - 1] = math_max(0, math_min(4, channel / 255 * scale))
		end

		bytes = string.sub(template, 1, GLOW_VALUE_OFFSET) .. ffi.string(rgb, 12) .. string.sub(template, GLOW_VALUE_OFFSET + 13)
	end

	local path = SOUL_PAYLOAD_DIR .. GLOW_MATERIAL_FILE
	local existing = lua_io.open(path, "rb")
	local current = existing and existing:read("*a")

	if existing then
		existing:close()
	end

	if current ~= bytes then
		local out = lua_io.open(path, "wb")

		if out then
			out:write(bytes)
			out:close()
		else
			mod:info("las glow colour: cannot write %s, shipped default used", path)
		end
	end
end

local function bake_soul_materials()
	local lua = rawget(_G, "Mods") and Mods.lua
	local ffi = lua and lua.ffi
	local lua_io = lua and lua.io

	if not ffi or not lua_io then
		mod:info("soulblaze colours: no file access, shipped defaults used")
		return
	end

	local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. SOUL_TEMPLATE_FILE, "rb")

	if not template_file then
		mod:info("soulblaze colours: template missing, shipped defaults used")
		return
	end

	local template = template_file:read("*a")

	template_file:close()

	if not template or #template ~= SOUL_TEMPLATE_SIZE then
		return
	end

	local saturation, brightness = soul_bake_profile()
	local saturation_step = math_floor(saturation * SOUL_SATURATION_STEPS + 0.5)
	local brightness_step = math_max(MIN_BRIGHTNESS_STEP, math_min(MAX_BRIGHTNESS_STEP, brightness))
	local value = ffi.new("float[1]")

	for i = 1, #SOUL_SLOTS do
		local hue_step = math_floor((i - 1) / #SOUL_SLOTS * SOUL_HUE_STEPS)

		value[0] = 1000 + saturation_step + (hue_step * 16 + brightness_step) / 16384

		local bytes = string.sub(template, 1, SOUL_VALUE_OFFSET) .. ffi.string(value, 4) .. string.sub(template, SOUL_VALUE_OFFSET + 5)
		local path = SOUL_PAYLOAD_DIR .. soul_material_file(SOUL_SLOTS[i])
		local existing = lua_io.open(path, "rb")
		local current = existing and existing:read("*a")

		if existing then
			existing:close()
		end

		if current ~= bytes then
			local out = lua_io.open(path, "wb")

			if out then
				out:write(bytes)
				out:close()
			else
				mod:info("soulblaze colours: cannot write %s, shipped default used", path)
			end
		end
	end
end

local GLOW_REDIRECTS = {
	{
		stock = "data/bc/bc95c93681c9f0f7",
		file = "bc95c93681c9f0f7.livehsv",
		sha256 = "2b6f58f49b2a07452e2593abdd1c2e92c94c2cb1bdee7f80dd20b7bb1e0eb684",
	},
	{
		stock = "data/zz/f0f0000000000101",
		file = "f0f0000000000101.glowpal",
		virtual = true,
	},
	{
		stock = "data/zz/f0f0000000000102",
		file = "f0f0000000000102.glowpal",
		virtual = true,
	},
	{
		stock = "6c363592a35f5599",
		file = "6c363592a35f5599.glowslot",
		sha256 = "8ab4b5e21781b700051df420a400b0f3ae028ca7d272640eb38571936f405c4f",
	},
	{
		stock = "data/zz/f0f0000000000007",
		file = "f0f0000000000007.glowpal",
		virtual = true,
	},
	{
		stock = "88cedce8a498f97e",
		file = "88cedce8a498f97e.glowslot",
		sha256 = "4dea34a5d7d323d046af778991c008e2352982a0d2b8106cf1860566d8bc0f96",
	},
	{
		stock = "data/zz/f0f0000000000008",
		file = "f0f0000000000008.glowpal",
		virtual = true,
	},
	{
		stock = "d932eac771ff85ae",
		file = "d932eac771ff85ae.glowslot",
		sha256 = "38d3c5c84bab2547f5ecd0c17d2f0658295f4ffd137b2a828a149404d58ee782",
	},
	{
		stock = "data/zz/f0f0000000000009",
		file = "f0f0000000000009.glowpal",
		virtual = true,
	},
	{
		stock = "81686d16269ea030",
		file = "81686d16269ea030.glowslot",
		sha256 = "89d512bf2f590d966944fa3cd71d3ce262f7ac8aad3b9e789f46731cd29c8cd1",
	},
	{
		stock = "data/zz/f0f000000000000a",
		file = "f0f000000000000a.glowpal",
		virtual = true,
	},
	{
		stock = "43fcfaba468316d8",
		file = "43fcfaba468316d8.glowslot",
		sha256 = "8a0c6162946fcb7e99f43ccecac541773b9ace84973ce0fea77c3d3271426e1b",
	},
	{
		stock = "data/zz/f0f000000000000b",
		file = "f0f000000000000b.glowpal",
		virtual = true,
	},
	{
		stock = "ff966c81581e8207",
		file = "ff966c81581e8207.glowslot",
		sha256 = "0146e4e7e09303bdcafaf56305ba6dcdb64328fa826432ddc64bea2520524998",
	},
	{
		stock = "data/zz/f0f000000000000c",
		file = "f0f000000000000c.glowpal",
		virtual = true,
	},
}

for i = 1, #GLOW_REDIRECTS do
	REDIRECTS[#REDIRECTS + 1] = GLOW_REDIRECTS[i]
end

for i = 1, #SOUL_SLOTS do
	local slot = SOUL_SLOTS[i]

	REDIRECTS[#REDIRECTS + 1] = { stock = slot.bundle, file = slot.bundle .. ".soulslot", sha256 = slot.bundle_sha256 }
	slot.bundle_redirect = #REDIRECTS
	REDIRECTS[#REDIRECTS + 1] = { stock = slot.material, file = soul_material_file(slot), sha256 = slot.material_sha256 }
	slot.material_redirect = #REDIRECTS
end

local BURN_BUNDLES = {
	{ bundle = "3d574968047de622", sha256 = "6dd0375c40c895e581ded45e0aac09a6e1c2f4a48c9dcaea993410a06a005471", package = "content/fx/particles/enemies/buff_burning" },
	{ bundle = "ec588082b617bc4d", sha256 = "cb962d2a7df373986633cff3efaa12f17b5bcbf00368c855478162d4aab45fdc", package = "content/fx/particles/enemies/buff_burning_stack_lvl02" },
	{ bundle = "a9dfcc3f7330140a", sha256 = "02ac7bca710a567d729e2f8bd133da3519bce1708b70d5b8315737fb1f217de0", package = "content/fx/particles/enemies/buff_burning_stack_lvl03" },
}

for i = 1, #BURN_BUNDLES do
	REDIRECTS[#REDIRECTS + 1] = { stock = BURN_BUNDLES[i].bundle, file = BURN_BUNDLES[i].bundle .. ".pyro", sha256 = BURN_BUNDLES[i].sha256 }
end

for layer = 1, #BURN_LAYERS do
	for slot = 1, BURN_PALETTE_SLOTS do
		REDIRECTS[#REDIRECTS + 1] = { stock = burn_material_loose(layer, slot), file = burn_material_file(layer, slot), virtual = true }
	end
end

REDIRECTS[#REDIRECTS + 1] = { stock = "data/zz/f0f5000000001f01", file = "3586b12003ab11fc.livehsv", virtual = true }
REDIRECTS[#REDIRECTS + 1] = { stock = "data/zz/f0f5000000001f02", file = "5b86a311c0ac5cf0.livehsv", virtual = true }

bake_soul_materials()

local BURN_BAKE_SOURCES = { "flamer_mine_", "flamer_team_", "skull_mine_", "skull_team_" }

local function burn_bake_profile()
	for _, prefix in ipairs(BURN_BAKE_SOURCES) do
		local mode = mod:get(prefix .. "mode") or "stock"

		if mod:get(prefix .. "show") ~= false and mode ~= "stock" then
			local saturation = 1
			local colour = mod:get(prefix .. "colour")

			if mode ~= "rainbow" and type(colour) == "table" then
				local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
				local high = math_max(r, g, b)

				saturation = high > 0 and (high - math_min(r, g, b)) / high or 0
			end

			return saturation, mod:get(prefix .. "brightness") or STOCK_BRIGHTNESS_STEP
		end
	end

	return 1, STOCK_BRIGHTNESS_STEP
end

local function bake_burn_materials()
	local lua = rawget(_G, "Mods") and Mods.lua
	local ffi = lua and lua.ffi
	local lua_io = lua and lua.io

	if not ffi or not lua_io then
		mod:info("burn colours: no file access, shipped defaults used")
		return
	end

	local saturation, brightness = burn_bake_profile()
	local saturation_step = math_floor(saturation * SOUL_SATURATION_STEPS + 0.5)
	local brightness_step = math_max(MIN_BRIGHTNESS_STEP, math_min(MAX_BRIGHTNESS_STEP, brightness))
	local value = ffi.new("float[1]")

	for layer = 1, #BURN_LAYERS do
		local spec = BURN_LAYERS[layer]
		local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. spec.template, "rb")
		local template = template_file and template_file:read("*a")

		if template_file then
			template_file:close()
		end

		if template and #template == spec.size then
			for slot = 1, BURN_PALETTE_SLOTS do
				local hue_step = math_floor((slot - 1) / BURN_PALETTE_SLOTS * SOUL_HUE_STEPS)

				value[0] = 1000 + saturation_step + (hue_step * 16 + brightness_step) / 16384

				local bytes = string.sub(template, 1, spec.offset) .. ffi.string(value, 4) .. string.sub(template, spec.offset + 5)
				local path = SOUL_PAYLOAD_DIR .. burn_material_file(layer, slot)
				local existing = lua_io.open(path, "rb")
				local current = existing and existing:read("*a")

				if existing then
					existing:close()
				end

				if current ~= bytes then
					local out = lua_io.open(path, "wb")

					if out then
						out:write(bytes)
						out:close()
					else
						mod:info("burn colours: cannot write %s", path)
					end
				end
			end
		else
			mod:info("burn colours: template %s missing or wrong size", spec.template)
		end
	end
end

bake_burn_materials()
local PLASMA_TRAIL_TEMPLATE = "c9a22ea5418d46c4.plasmatemplate"
local PLASMA_TRAIL_SIZE = 115920
local PLASMA_TRAIL_OFFSET = 328
local PLASMA_TRAIL_SLOTS = {
	{ file = "f0f0000000000901.plasmapal", name = "\31\215\71\224\127\72\39\252" },
	{ file = "f0f0000000000902.plasmapal", name = "\168\247\196\175\120\157\17\12" },
	{ file = "f0f0000000000903.plasmapal", name = "\86\31\230\40\154\61\162\12" },
	{ file = "f0f0000000000904.plasmapal", name = "\165\117\61\166\95\205\86\197" },
	{ file = "f0f0000000000905.plasmapal", name = "\110\237\38\56\188\247\87\223" },
	{ file = "f0f0000000000906.plasmapal", name = "\38\87\66\155\225\146\109\126" },
	{ file = "f0f0000000000907.plasmapal", name = "\53\216\93\40\180\129\196\174" },
	{ file = "f0f0000000000908.plasmapal", name = "\237\106\184\213\197\127\188\31" },
	{ file = "f0f0000000000909.plasmapal", name = "\232\168\238\210\232\12\248\55" },
	{ file = "f0f000000000090a.plasmapal", name = "\156\39\211\204\138\223\81\164" },
	{ file = "f0f000000000090b.plasmapal", name = "\182\0\199\225\63\100\113\86" },
	{ file = "f0f000000000090c.plasmapal", name = "\133\11\188\236\167\89\31\188" },
}

local function bake_plasma_trail()
	local lua = rawget(_G, "Mods") and Mods.lua
	local ffi = lua and lua.ffi
	local lua_io = lua and lua.io

	if not ffi or not lua_io then
		return
	end

	local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. PLASMA_TRAIL_TEMPLATE, "rb")
	local template = template_file and template_file:read("*a")

	if template_file then
		template_file:close()
	end

	if not template or #template ~= PLASMA_TRAIL_SIZE then
		mod:info("plasma trail palette: template missing or wrong size")

		return
	end

	local mode = mod:get("plasma_mine_mode")
	local shown = mod:get("plasma_mine_show") ~= false and (mode == "custom" or mode == "rainbow")
	local brightness = math_max(1, math_min(15, mod:get("plasma_mine_brightness") or STOCK_BRIGHTNESS_STEP))
	local saturation_step = 15

	if mode == "custom" then
		local colour = mod:get("plasma_mine_colour")

		if type(colour) == "table" then
			local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
			local high, low = math_max(r, g, b), math_min(r, g, b)

			saturation_step = math_floor((high > 0 and (high - low) / high or 0) * 15 + 0.5)
		end
	end

	for i = 1, #PLASMA_TRAIL_SLOTS do
		local slot = PLASMA_TRAIL_SLOTS[i]
		local bytes = template

		if shown then
			local value = ffi.new("float[1]")
			local hue = (i - 1) / #PLASMA_TRAIL_SLOTS

			value[0] = 1000 + saturation_step + (math_floor(hue * 1024) % 1024 * 16 + brightness) / 16384
			bytes = string.sub(template, 1, PLASMA_TRAIL_OFFSET) .. ffi.string(value, 4) .. string.sub(template, PLASMA_TRAIL_OFFSET + 5)
		end

		local path = SOUL_PAYLOAD_DIR .. slot.file
		local existing = lua_io.open(path, "rb")
		local current = existing and existing:read("*a")

		if existing then
			existing:close()
		end

		if current ~= bytes then
			local out = lua_io.open(path, "wb")

			if out then
				out:write(bytes)
				out:close()
			else
				mod:info("plasma trail palette: cannot write %s", path)
			end
		end
	end
end
bake_glow_material()
bake_glow_palette()
bake_surface_glow()
bake_impact_glow()
bake_plasma_trail()

local asset_redirect = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/asset_redirect")
local REDIRECT_CONTRACT = "polychromatic_jet/live_hsv"
local _redirect_handles = {}

if asset_redirect then
	for i = 1, #REDIRECTS do
		local entry = REDIRECTS[i]

		_redirect_handles[i] = asset_redirect.register(mod, {
			stock = entry.stock,
			file = "payload/" .. entry.file,
			sha256 = entry.sha256,
			virtual = entry.virtual,
			priority = 0,
			contract = REDIRECT_CONTRACT,
		})
	end
end

local VARIABLE = "lighting_far_range"
local STOCK_VALUE = 1000
local HUE_STEPS = 1024
local SATURATION_STEPS = 15
local CODE_DIVISOR = 16384
local MAX_CLOUDS = 16
local DIRECT_CLOUD = "beam"
local DIRECT_EFFECTS = {
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam"] = "beam_color",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_crit"] = "color_a",
}
local CLOUDS = {}

for i = 1, MAX_CLOUDS do
	CLOUDS[i] = "polychromatic_jet_" .. i
end

local SETS = {
	{ id = "staff", categories = { "mine", "team" } },
	{ id = "flamer", categories = { "mine", "team" } },
	{ id = "skull", categories = { "mine", "team" } },
	{ id = "las", categories = { "mine", "team" } },
	{ id = "plasma", categories = { "mine", "team" } },
	{ id = "greatsword", categories = { "mine", "team" } },
	{ id = "sniper", categories = { "enemy" } },
}

local RAINBOW_CYCLES_PER_SECOND = 0.25
local _profiles = {}
local _soulblaze_enabled = true
local _flamer_burn_enabled = true
local _skull_burn_enabled = true
local _burn_patch_served = false

for i = 1, #SETS do
	local set = SETS[i]
	local by_category = {}

	for j = 1, #set.categories do
		by_category[set.categories[j]] = { show = true, mode = "stock", hue = 0, saturation = 1, brightness = STOCK_BRIGHTNESS_STEP }
	end

	_profiles[set.id] = by_category
end

local function rgb_to_hsv(r, g, b)
	local max = math_max(r, g, b)
	local min = math_min(r, g, b)
	local delta = max - min
	local hue = 0

	if delta > 0 then
		if max == r then
			hue = ((g - b) / delta) % 6
		elseif max == g then
			hue = (b - r) / delta + 2
		else
			hue = (r - g) / delta + 4
		end

		hue = hue / 6
	end

	local saturation = max > 0 and delta / max or 0

	return hue, saturation, max
end

local function cache_settings()
	_soulblaze_enabled = mod:get("soulblaze") ~= false
	_flamer_burn_enabled = mod:get("flamer_burn") ~= false
	_skull_burn_enabled = mod:get("skull_burn") ~= false

	for set_id, by_category in pairs(_profiles) do
		for category, profile in pairs(by_category) do
			local prefix = set_id .. "_" .. category .. "_"

			profile.show = mod:get(prefix .. "show") ~= false
			profile.mode = mod:get(prefix .. "mode") or "stock"
			profile.brightness = mod:get(prefix .. "brightness") or STOCK_BRIGHTNESS_STEP

			local colour = mod:get(prefix .. "colour")

			if type(colour) == "table" then
				profile.hue, profile.saturation = rgb_to_hsv((colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255)
			end
		end
	end
end

local function profile_for(set_id, category)
	local by_category = _profiles[set_id]

	return by_category and by_category[category]
end

local function encoded_value(profile, t)
	local mode = profile.mode

	if mode == "stock" then
		return STOCK_VALUE
	end

	local hue = profile.hue
	local saturation = profile.saturation

	if mode == "rainbow" then
		local phase = t * RAINBOW_CYCLES_PER_SECOND

		hue = phase - math_floor(phase)
		saturation = 1
	end

	local hue_step = math_floor(hue * HUE_STEPS) % HUE_STEPS
	local saturation_step = math_floor(saturation * SATURATION_STEPS + 0.5)
	local brightness_step = math_floor(profile.brightness + 0.5)

	if brightness_step < MIN_BRIGHTNESS_STEP then
		brightness_step = MIN_BRIGHTNESS_STEP
	elseif brightness_step > MAX_BRIGHTNESS_STEP then
		brightness_step = MAX_BRIGHTNESS_STEP
	end

	return STOCK_VALUE + saturation_step + (hue_step * 16 + brightness_step) / CODE_DIVISOR
end

local _gameplay_running = false

local function tint(world, particle_id, value)
	if not _gameplay_running then
		return false
	end

	if not World_are_particles_playing(world, particle_id) then
		return true
	end

	local written = 0

	for i = 1, MAX_CLOUDS do
		local cloud = CLOUDS[i]

		if World_has_particles_material(world, particle_id, cloud) then
			World_set_particles_material_scalar(world, particle_id, cloud, VARIABLE, value)

			written = written + 1
		end
	end

	return written > 0
end

local function gameplay_time()
	local time_manager = Managers.time

	return time_manager:has_timer("gameplay") and time_manager:time("gameplay") or 0
end

local function local_player_unit()
	local player = Managers.player:local_player_safe(1)

	return player and player.player_unit
end

local function category_of_unit(unit)
	if not unit then
		return "enemy"
	end

	if unit == local_player_unit() then
		return "mine"
	end

	local player_unit_spawn = Managers.state.player_unit_spawn

	if player_unit_spawn and player_unit_spawn:owner(unit) then
		return "team"
	end

	return "enemy"
end

local function player_category(unit)
	local category = category_of_unit(unit)

	return category == "enemy" and "team" or category
end

local function hsv_to_rgb(h, s, v)
	local i = math_floor(h * 6) % 6
	local f = h * 6 - math_floor(h * 6)
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local w = v * (1 - (1 - f) * s)

	if i == 0 then
		return v, w, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, w
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return w, p, v
	end

	return v, p, q
end

local function profile_rgb(profile, t)
	local hue = profile.hue
	local saturation = profile.saturation

	if profile.mode == "rainbow" then
		local phase = t * RAINBOW_CYCLES_PER_SECOND

		hue = phase - math_floor(phase)
		saturation = 1
	end

	return hsv_to_rgb(hue, saturation, profile.brightness / STOCK_BRIGHTNESS_STEP)
end

local function tint_direct(world, particle_id, variable, profile)
	if not _gameplay_running then
		return false
	end

	if profile.mode == "stock" or not World_are_particles_playing(world, particle_id) then
		return true
	end

	if not World_has_particles_material(world, particle_id, DIRECT_CLOUD) then
		return false
	end

	local r, g, b = profile_rgb(profile, gameplay_time())

	World_set_particles_material_vector3(world, particle_id, DIRECT_CLOUD, variable, Vector3(r, g, b))

	return true
end

local FLASH_LERP_VARIABLE = "lerp_color_a"

local SPAWN_VECTOR_CLOUDS = {
	["content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle"] = {
		["polychromatic_jet_3"] = FLASH_LERP_VARIABLE,
		["polychromatic_jet_4"] = FLASH_LERP_VARIABLE,
	},
	["content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle_crit"] = {
		["polychromatic_jet_3"] = FLASH_LERP_VARIABLE,
		["polychromatic_jet_4"] = FLASH_LERP_VARIABLE,
	},
	["content/fx/particles/weapons/rifles/lasgun/lasgun_charged_muzzle"] = {
		["polychromatic_jet_3"] = FLASH_LERP_VARIABLE,
		["polychromatic_jet_4"] = FLASH_LERP_VARIABLE,
	},
	["content/fx/particles/weapons/rifles/lasgun/lasgun_charged_muzzle_crit"] = {
		["polychromatic_jet_3"] = FLASH_LERP_VARIABLE,
		["polychromatic_jet_4"] = FLASH_LERP_VARIABLE,
	},
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle"] = {
		["polychromatic_jet_1"] = FLASH_LERP_VARIABLE,
		["polychromatic_jet_2"] = FLASH_LERP_VARIABLE,
	},
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_crit"] = {
		["polychromatic_jet_1"] = FLASH_LERP_VARIABLE,
		["polychromatic_jet_2"] = FLASH_LERP_VARIABLE,
	},
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_elysian"] = {
		["polychromatic_jet_1"] = FLASH_LERP_VARIABLE,
		["polychromatic_jet_2"] = FLASH_LERP_VARIABLE,
	},
	["content/fx/particles/weapons/rifles/laspistol/laspistol_heavy_muzzle"] = {
		["polychromatic_jet_1"] = FLASH_LERP_VARIABLE,
		["polychromatic_jet_2"] = FLASH_LERP_VARIABLE,
	},
	["content/fx/particles/weapons/rifles/laspistol/laspistol_heavy_muzzle_crit"] = {
		["polychromatic_jet_1"] = FLASH_LERP_VARIABLE,
		["polychromatic_jet_2"] = FLASH_LERP_VARIABLE,
	},
	["content/fx/particles/weapons/rifles/laspistol/laspistol_muzzle"] = {
		["polychromatic_jet_1"] = FLASH_LERP_VARIABLE,
		["polychromatic_jet_2"] = FLASH_LERP_VARIABLE,
	},
}

local function tint_mixed(world, particle_id, profile, vector_clouds)
	if not _gameplay_running then
		return false
	end

	if not World_are_particles_playing(world, particle_id) then
		return true
	end

	local t = gameplay_time()
	local value = encoded_value(profile, t)
	local r, g, b = profile_rgb(profile, t)
	local written = 0

	for i = 1, MAX_CLOUDS do
		local cloud = CLOUDS[i]

		if World_has_particles_material(world, particle_id, cloud) then
			local vector_variable = vector_clouds[cloud]

			if vector_variable then
				World_set_particles_material_vector3(world, particle_id, cloud, vector_variable, Vector3(r, g, b))
			else
				World_set_particles_material_scalar(world, particle_id, cloud, VARIABLE, value)
			end

			written = written + 1
		end
	end

	return written > 0
end

local function apply_spawn(world, particle_id, profile, variable, effect_name)
	local vector_clouds = effect_name and SPAWN_VECTOR_CLOUDS[effect_name]

	if profile.mode == "hidden" then
		World_stop_spawning_particles(world, particle_id)

		return true
	elseif not profile.show or profile.mode == "stock" then
		return true
	elseif variable then
		return tint_direct(world, particle_id, variable, profile)
	elseif vector_clouds then
		return tint_mixed(world, particle_id, profile, vector_clouds)
	end

	return tint(world, particle_id, encoded_value(profile, gameplay_time()))
end

local FLASH_TINT_VARIABLE = "material_variable_76952f42_25134716_0e97137b"
local FLASH_EFFECTS = {
	["content/fx/particles/enemies/renegade_sniper/renegade_sniper_muzzle_flash"] = { variable = FLASH_LERP_VARIABLE, clouds = 2 },
	["content/fx/particles/enemies/renegade_sniper/renegade_sniper_beam_emitter"] = { variable = FLASH_TINT_VARIABLE, clouds = 1 },
	["content/fx/particles/enemies/sniper_scope_flash"] = { variable = FLASH_TINT_VARIABLE, clouds = 2 },
}

local function apply_flash(world, particle_id, flash, profile)
	if not _gameplay_running then
		return false
	end

	if profile.mode == "hidden" then
		World_stop_spawning_particles(world, particle_id)

		return true
	end

	if not profile.show or profile.mode == "stock" or not World_are_particles_playing(world, particle_id) then
		return true
	end

	local r, g, b = profile_rgb(profile, gameplay_time())
	local written = 0

	for i = 1, flash.clouds do
		local cloud = CLOUDS[i]

		if World_has_particles_material(world, particle_id, cloud) then
			World_set_particles_material_vector3(world, particle_id, cloud, flash.variable, Vector3(r, g, b))

			written = written + 1
		end
	end

	return written > 0
end

local PENDING_TINT_FRAMES = 30
local _pending_tints = {}

local function apply_or_defer(world, particle_id, apply, first, second, third)
	if apply(world, particle_id, first, second, third) then
		return
	end

	_pending_tints[#_pending_tints + 1] = {
		world = world,
		particle_id = particle_id,
		apply = apply,
		first = first,
		second = second,
		third = third,
		frames = 0,
	}
end

local function retry_pending_tints()
	if not _gameplay_running then
		return
	end

	for i = #_pending_tints, 1, -1 do
		local entry = _pending_tints[i]

		entry.frames = entry.frames + 1

		if entry.apply(entry.world, entry.particle_id, entry.first, entry.second, entry.third) or entry.frames >= PENDING_TINT_FRAMES then
			table.remove(_pending_tints, i)
		end
	end
end

local function clear_pending_tints()
	for i = #_pending_tints, 1, -1 do
		_pending_tints[i] = nil
	end
end

local STAFF_IMPACT_EFFECT = "content/fx/particles/weapons/flame_staff/psyker_flame_staff_impact_delay"
local FLAMER_IMPACT_EFFECT = "content/fx/particles/weapons/rifles/zealot_flamer/zealot_flamer_impact_delay"

local ENCODED_EFFECTS = {
	["content/fx/particles/enemies/cultist_flamer/cultist_flame_thrower"] = "flamer",
	["content/fx/particles/enemies/lasgun_beam_enemy"] = "las",
	["content/fx/particles/enemies/renegade_flamer/renegade_flame_thrower"] = "flamer",
	["content/fx/particles/enemies/renegade_sniper/renegade_sniper_beam"] = "sniper",
	["content/fx/particles/enemies/renegade_sniper/renegade_sniper_beam_outdoors"] = "sniper",
	["content/fx/particles/enemies/sniper_laser_sight"] = "sniper",
	["content/fx/particles/impacts/surfaces/impact_snow_laser_01"] = "las",
	["content/fx/particles/impacts/weapons/lasgun/lasgun_impact_player"] = "las",
	["content/fx/particles/impacts/weapons/lasgun/lasgun_impact_surface_player"] = "las",
	["content/fx/particles/impacts/weapons/lasgun/lasgun_sparks_armor_player"] = "las",
	["content/fx/particles/impacts/weapons/lasgun/super_armor_lasgun"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_elysian"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_charged"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_linger"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_linger_bfg"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_standard_linger"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_standard_linger_enemy"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle_crit"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_charged_muzzle"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_charged_muzzle_crit"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_crit_trail"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_crit"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_elysian"] = "las",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_enemy"] = "las",
	["content/fx/particles/weapons/rifles/laspistol/lasgun_heavy_beam_crit_trail"] = "las",
	["content/fx/particles/weapons/rifles/laspistol/laspistol_heavy_muzzle"] = "las",
	["content/fx/particles/weapons/rifles/laspistol/laspistol_heavy_muzzle_crit"] = "las",
	["content/fx/particles/weapons/rifles/laspistol/laspistol_muzzle"] = "las",
	["content/fx/particles/impacts/weapons/force_sword/force_sword_impact_02"] = "greatsword",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_charge"] = "greatsword",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_special_high"] = "greatsword",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_special_low"] = "greatsword",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_special_middle"] = "greatsword",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_stage2"] = "greatsword",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_stage2_loop"] = "greatsword",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_wisps_fingerstips"] = "greatsword",
	["content/fx/particles/weapons/swords/forcesword/psyker_activate_forcesword"] = "greatsword",
	["content/fx/particles/weapons/swords/forcesword/psyker_block"] = "greatsword",
	["content/fx/particles/weapons/swords/forcesword/psyker_parry"] = "greatsword",
	["content/fx/particles/weapons/swords/forcesword/psyker_push"] = "greatsword",
	["content/fx/particles/enemies/renegade_plasma_trooper/renegade_plasma_explosion_medium"] = "plasma",
	["content/fx/particles/enemies/renegade_plasma_trooper/renegade_plasma_flash"] = "plasma",
	["content/fx/particles/enemies/renegade_plasma_trooper/renegade_plasma_muzzle"] = "plasma",
	["content/fx/particles/impacts/surfaces/plasma_charged_explosion_small_snow"] = "plasma",
	["content/fx/particles/impacts/weapons/plasma_gun/plasma_gun_impact_large"] = "plasma",
	["content/fx/particles/impacts/weapons/plasma_gun/plasma_gun_impact_small"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_beam"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_linger"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_linger_orange"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_orange"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_charged_explosion_large"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_charged_explosion_medium"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_charged_explosion_small"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_gun_charge"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_muzzle_bfg"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_muzzle_captain"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_muzzle_ks"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_overcharge_level01"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_overcharge_level02"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_overcharge_level03"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_penetration_01"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_reload"] = "plasma",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_vent_valve"] = "plasma",
}

local _spawn_context = {}
local _spawn_context_active = false
local _spawn_owner = nil

local function redshift_owns_sniper()
	local redshift = get_mod("Redshift")

	return redshift ~= nil and redshift:is_enabled()
end

local SNIPER_GROUP_ID = "sniper_group"
local _sniper_group_title = mod:localize(SNIPER_GROUP_ID)

local function strip_markup(text)
	if type(text) ~= "string" then
		return nil
	end

	return (text:gsub("{#.-}", ""))
end

local function set_group_data_title(widgets, title)
	for i = 1, #widgets do
		local data = widgets[i]

		if type(data) == "table" then
			if type(data.options) == "table" then
				for j = 1, #data.options do
					local option = data.options[j]

					if type(option) == "table" and option.value == SNIPER_GROUP_ID then
						option.text = title
						option.display_name = title
					end
				end
			end

			if data.setting_id == SNIPER_GROUP_ID then
				data.title = title
				data.display_name = title

				return true
			end

			if type(data.sub_widgets) == "table" and set_group_data_title(data.sub_widgets, title) then
				return true
			end
		end
	end

	return false
end

local function set_open_view_title(old_title, title)
	local ui_manager = Managers.ui
	local view = ui_manager and ui_manager:view_instance("dmf_options_view")
	local categories = view and view._settings_category_widgets

	if not categories then
		return
	end

	local old_clean = strip_markup(old_title)

	for _, widgets in pairs(categories) do
		for i = 1, #widgets do
			local widget = widgets[i] and widgets[i].widget
			local content = widget and widget.content

			if content and strip_markup(content.text) == old_clean then
				if content.entry then
					content.entry.display_name = title
					content.entry.title = title
				end

				content.text = title
				widget.dirty = true

				return
			end
		end
	end
end

local function refresh_sniper_group_title()
	local title = mod:localize(redshift_owns_sniper() and "sniper_group_redshift" or "sniper_group_plain")

	if title == _sniper_group_title then
		return
	end

	local old_title = _sniper_group_title
	local dmf = get_mod("DMF")
	local all_widgets = dmf and dmf.options_widgets_data

	_sniper_group_title = title

	if type(all_widgets) == "table" then
		local name = mod:get_name()

		for i = 1, #all_widgets do
			local mod_widgets = all_widgets[i]

			if type(mod_widgets) == "table" and mod_widgets[1] and mod_widgets[1].mod_name == name then
				set_group_data_title(mod_widgets, title)

				break
			end
		end
	end

	set_open_view_title(old_title, title)
end

mod:hook_safe(get_mod("DMF"), "set_mod_state", function(target_mod)
	if target_mod and target_mod.get_name and target_mod:get_name() == "Redshift" then
		refresh_sniper_group_title()
	end
end)

local _glow_load_ids = rawget(_G, "__polychromatic_glow_packages") or {}
local _glow_slots_loaded = false

rawset(_G, "__polychromatic_glow_packages", _glow_load_ids)

local EXTENDED_PACKAGES = {
	{ bundle = "a2bdefafc2bcdcf1", package = "content/fx/particles/weapons/foce_sword/forcesword_2h_special_low" },
	{ bundle = "3d574968047de622", package = "content/fx/particles/enemies/buff_burning" },
	{ bundle = "ec588082b617bc4d", package = "content/fx/particles/enemies/buff_burning_stack_lvl02" },
	{ bundle = "a9dfcc3f7330140a", package = "content/fx/particles/enemies/buff_burning_stack_lvl03" },
	{ bundle = "c0c865abfb9f366a", package = "content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_linger" },
	{ bundle = "f6f1954051323147", package = "content/fx/particles/impacts/weapons/lasgun/lasgun_impact_player" },
	{ bundle = "689dc94618cb3a45", package = "content/fx/particles/impacts/weapons/lasgun/lasgun_impact_surface_player" },
	{ bundle = "038a622c4f8dae2c", package = "content/fx/particles/impacts/weapons/lasgun/lasgun_sparks_armor_player" },
	{ bundle = "f9a026d45df7bcea", package = "content/fx/particles/impacts/surfaces/impact_snow_laser_01" },
	{ bundle = "612e6312440e0738", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_charged" },
	{ bundle = "09cba8bbfcd95fe1", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_linger" },
	{ bundle = "4a23053559b62d82", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_linger_bfg" },
	{ bundle = "d39791625c6317ee", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle" },
	{ bundle = "9a67cf5c0db091b7", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle_crit" },
	{ bundle = "348d27134018dd32", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_charged_muzzle" },
	{ bundle = "d753d8a1655a082f", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_charged_muzzle_crit" },
	{ bundle = "f038b72029cdfd17", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_crit_trail" },
	{ bundle = "ec4de4ad48cd9642", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle" },
	{ bundle = "07b2d9094a94893e", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_crit" },
	{ bundle = "14a1118d1b478a79", package = "content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_elysian" },
	{ bundle = "e064bea4d1676af6", package = "content/fx/particles/weapons/rifles/laspistol/lasgun_heavy_beam_crit_trail" },
	{ bundle = "06c8bd5dcfb5e7eb", package = "content/fx/particles/weapons/rifles/laspistol/laspistol_heavy_muzzle" },
	{ bundle = "65fffac97bc7ff98", package = "content/fx/particles/weapons/rifles/laspistol/laspistol_heavy_muzzle_crit" },
	{ bundle = "0248bd48defd788e", package = "content/fx/particles/weapons/rifles/laspistol/laspistol_muzzle" },
}
local _extended_load_ids = rawget(_G, "__polychromatic_extended_packages") or {}

rawset(_G, "__polychromatic_extended_packages", _extended_load_ids)

local function pin_extended_packages()
	if not Managers.package then
		return
	end

	for i = 1, #EXTENDED_PACKAGES do
		local entry = EXTENDED_PACKAGES[i]

		if not _extended_load_ids[entry.package] then
			for k = 1, #REDIRECTS do
				if REDIRECTS[k].stock == entry.bundle and redirect_served(asset_redirect.state(_redirect_handles[k])) then
					_extended_load_ids[entry.package] = Managers.package:load(entry.package, "Polychromatic", nil, true)
				end
			end
		end
	end
end

local function load_glow_slots()
	if not Managers.package then
		return
	end

	for _, list in pairs(GLOW_SLOTS) do
		for i = 1, #list do
			local slot = list[i]

			if slot.usable and not _glow_load_ids[slot.package] then
				_glow_load_ids[slot.package] = Managers.package:load(slot.package, "Polychromatic", nil, true)
			end
		end
	end
end

local function glow_slots_ready()
	if _glow_slots_loaded then
		return true
	end

	for _, list in pairs(GLOW_SLOTS) do
		for i = 1, #list do
			local slot = list[i]

			if slot.usable then
				local id = _glow_load_ids[slot.package]

				if not id or not Managers.package:has_loaded_id(id) then
					return false
				end
			end
		end
	end

	_glow_slots_loaded = true

	return true
end

local GLOW_PARTICLE_PALETTES = {
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_linger"] = {
		set = "plasma",
		bundle = "c0c865abfb9f366a",
		names = {
			"\31\215\71\224\127\72\39\252",
			"\168\247\196\175\120\157\17\12",
			"\86\31\230\40\154\61\162\12",
			"\165\117\61\166\95\205\86\197",
			"\110\237\38\56\188\247\87\223",
			"\38\87\66\155\225\146\109\126",
			"\53\216\93\40\180\129\196\174",
			"\237\106\184\213\197\127\188\31",
			"\232\168\238\210\232\12\248\55",
			"\156\39\211\204\138\223\81\164",
			"\182\0\199\225\63\100\113\86",
			"\133\11\188\236\167\89\31\188",
		},
	},
	["content/fx/particles/impacts/weapons/lasgun/lasgun_impact_player"] = {
		bundle = "f6f1954051323147",
		names = {
			"\121\111\71\156\238\170\228\8",
			"\100\199\226\252\193\143\44\251",
			"\32\193\189\208\19\76\192\255",
			"\51\234\26\33\158\177\255\228",
			"\4\158\244\97\71\105\142\133",
			"\188\230\160\201\202\86\199\36",
			"\97\126\2\26\20\246\169\75",
			"\155\254\233\188\92\68\73\228",
			"\158\238\50\217\65\107\54\2",
			"\88\229\61\79\245\228\204\14",
			"\246\138\230\32\249\39\148\59",
			"\101\140\19\206\29\119\210\100",
		},
	},
	["content/fx/particles/impacts/weapons/lasgun/lasgun_impact_surface_player"] = {
		bundle = "689dc94618cb3a45",
		names = {
			"\56\151\152\21\12\208\113\243",
			"\85\152\146\64\251\245\27\23",
			"\102\64\130\51\227\144\87\144",
			"\102\203\98\199\31\89\158\212",
			"\125\175\144\11\212\137\192\70",
			"\193\88\254\108\55\60\218\116",
			"\30\2\202\75\53\233\208\252",
			"\236\230\170\189\148\123\248\155",
			"\40\60\54\89\97\57\164\177",
			"\84\233\104\136\170\116\169\88",
			"\98\165\169\220\33\175\187\64",
			"\43\111\188\199\122\171\144\101",
		},
	},
	["content/fx/particles/impacts/weapons/lasgun/lasgun_sparks_armor_player"] = {
		bundle = "038a622c4f8dae2c",
		names = {
			"\107\64\132\241\14\42\165\83",
			"\61\128\247\61\83\144\181\192",
			"\85\190\32\109\32\210\187\201",
			"\162\219\118\13\12\143\9\12",
			"\13\130\92\186\28\171\100\29",
			"\107\111\244\126\152\60\53\2",
			"\237\207\90\83\76\135\224\53",
			"\203\196\95\232\176\250\158\170",
			"\38\243\198\8\206\206\156\102",
			"\88\231\67\195\67\81\58\177",
			"\14\93\111\213\126\127\242\188",
			"\199\45\68\23\82\84\140\32",
		},
	},
	["content/fx/particles/impacts/surfaces/impact_snow_laser_01"] = {
		bundle = "f9a026d45df7bcea",
		names = {
			"\73\254\241\49\38\104\124\207",
			"\181\47\227\32\26\224\255\27",
			"\212\180\184\207\109\218\176\1",
			"\251\123\255\20\76\82\90\193",
			"\101\189\246\31\122\106\42\87",
			"\70\137\189\226\139\232\193\93",
			"\23\95\38\86\74\116\166\217",
			"\120\87\206\62\67\228\157\58",
			"\57\202\133\112\200\242\215\69",
			"\150\90\132\189\120\219\209\44",
			"\103\184\174\216\28\154\252\222",
			"\14\80\36\42\89\174\127\18",
		},
	},
	["content/fx/particles/weapons/foce_sword/forcesword_2h_special_low"] = {
		set = "greatsword",
		bundle = "a2bdefafc2bcdcf1",
		names = {
			"\64\204\121\195\60\203\190\72",
			"\250\67\207\113\153\34\166\191",
			"\110\205\60\145\28\127\172\129",
			"\119\248\155\84\72\139\89\143",
			"\114\157\235\202\77\40\149\220",
			"\169\48\160\171\142\182\223\217",
			"\220\163\39\81\222\16\61\173",
			"\63\151\93\71\37\63\190\90",
			"\203\180\146\16\164\76\67\15",
			"\199\142\222\182\130\149\239\61",
			"\200\42\187\156\168\101\32\42",
			"\137\183\55\24\87\150\20\6",
		},
	},
}
local _palette_ready = {}

local function palette_ready(entry)
	if _palette_ready[entry] then
		return true
	end

	_palette_ready[entry] = Application.can_get_resource("particles", entry.names[1]) == true

	return _palette_ready[entry]
end

local BURN_PALETTES = {
	["content/fx/particles/enemies/buff_burning"] = {
		"\89\102\56\241\105\22\160\0",
		"\211\42\137\243\74\238\252\115",
		"\21\118\41\160\50\48\184\231",
		"\223\102\219\160\168\69\30\239",
		"\217\44\207\20\255\13\114\179",
		"\233\62\209\61\6\71\157\28",
		"\172\169\195\41\68\31\21\146",
		"\201\224\116\23\230\215\7\248",
		"\76\100\239\117\104\69\225\79",
		"\105\100\42\225\172\121\207\6",
		"\39\188\22\84\184\149\17\46",
		"\80\251\172\35\17\179\37\7",
	},
	["content/fx/particles/enemies/buff_burning_stack_lvl02"] = {
		"\210\202\1\216\87\146\67\111",
		"\83\94\243\123\4\228\86\135",
		"\186\4\248\169\5\124\69\234",
		"\227\236\215\16\70\42\140\247",
		"\89\148\16\162\219\238\50\205",
		"\40\120\96\216\235\101\155\175",
		"\127\224\79\160\225\128\194\159",
		"\13\152\99\16\194\16\81\190",
		"\142\228\136\0\249\242\95\92",
		"\230\49\98\94\14\179\16\97",
		"\147\213\146\184\47\107\233\96",
		"\155\51\150\66\11\237\92\72",
	},
	["content/fx/particles/enemies/buff_burning_stack_lvl03"] = {
		"\241\50\27\169\23\80\207\176",
		"\185\230\111\2\59\239\12\232",
		"\209\143\84\93\117\235\210\76",
		"\138\171\243\28\9\16\109\19",
		"\253\18\113\210\66\178\30\127",
		"\71\189\168\208\87\43\37\17",
		"\39\218\38\201\126\2\149\104",
		"\130\105\254\232\222\203\44\75",
		"\161\247\148\142\54\42\52\89",
		"\138\105\29\22\67\88\168\114",
		"\84\20\28\59\13\197\122\12",
		"\60\136\208\139\162\178\62\146",
	},
}
local _burn_palette_ready = {}

local function burn_palette_name(effect_name)
	local palette = BURN_PALETTES[effect_name]
	local profile = palette and _spawn_context_active and _spawn_context[effect_name]

	if not profile or profile.mode == "stock" or profile.mode == "hidden" then
		return nil
	end

	if not _burn_palette_ready[palette] then
		_burn_palette_ready[palette] = Application.can_get_resource("particles", palette[1]) == true

		if not _burn_palette_ready[palette] then
			return nil
		end
	end

	local hue = profile.hue or 0

	if profile.mode == "rainbow" then
		local phase = gameplay_time() * RAINBOW_CYCLES_PER_SECOND

		hue = phase - math_floor(phase)
	end

	return palette[math_floor(hue * #palette + 0.5) % #palette + 1]
end

local function glow_slot_for(effect_name)
	local layer = GLOW_SOURCE_EFFECTS[effect_name]
	local palette = GLOW_PARTICLE_PALETTES[effect_name]
	local owner = _spawn_owner

	if layer then
		if owner ~= "mine" or not glow_slots_ready() then
			return nil
		end
	elseif not palette or not palette_ready(palette) then
		return nil
	elseif owner ~= "mine" and owner ~= "team" then
		return nil
	end

	local set_id = palette and palette.set or "las"
	local profile = profile_for(set_id, owner)

	if not profile or not profile.show or profile.mode == "stock" or profile.mode == "hidden" then
		return nil
	end

	local hue = profile.hue or 0

	if profile.mode == "rainbow" then
		local phase = gameplay_time() * RAINBOW_CYCLES_PER_SECOND

		hue = phase - math_floor(phase)
	end

	if palette then
		local names = palette.names

		return names[math_floor(hue * #names + 0.5) % #names + 1]
	end

	local list = GLOW_SLOTS[layer]
	local slot = list[math_floor(hue * #list + 0.5) % #list + 1]

	return slot.usable and slot.package or nil
end
local UNREACHABLE_EFFECTS = {
	["content/fx/particles/weapons/foce_sword/forcesword_2h_special_high"] = true,
}

mod:hook(World, "create_particles", function(func, world, effect_name, ...)
	local spawn_name = glow_slot_for(effect_name) or burn_palette_name(effect_name) or effect_name
	local particle_id = func(world, spawn_name, ...)

	if not particle_id then
		return particle_id
	end

	if UNREACHABLE_EFFECTS[effect_name] or BURN_PALETTES[effect_name] then
		return particle_id
	end

	local profile = _spawn_context_active and _spawn_context[effect_name]

	if profile then
		apply_or_defer(world, particle_id, apply_spawn, profile, nil, effect_name)

		return particle_id
	end

	local flash = FLASH_EFFECTS[effect_name]

	if flash then
		if not redshift_owns_sniper() then
			profile = profile_for("sniper", "enemy")

			if profile then
				apply_or_defer(world, particle_id, apply_flash, flash, profile)
			end
		end

		return particle_id
	end

	local variable = DIRECT_EFFECTS[effect_name]
	local set_id = variable and "las" or ENCODED_EFFECTS[effect_name]

	if not set_id then
		return particle_id
	end

	if set_id == "sniper" and redshift_owns_sniper() then
		return particle_id
	end

	profile = profile_for(set_id, _spawn_owner or "enemy")

	if profile then
		apply_or_defer(world, particle_id, apply_spawn, profile, variable, effect_name)
	end

	return particle_id
end)

local function clear_spawn_context()
	_spawn_context_active = false

	for effect_name in pairs(_spawn_context) do
		_spawn_context[effect_name] = nil
	end
end

local function call_with_spawn_context(func, ...)
	local ok, result = pcall(func, ...)

	clear_spawn_context()

	if not ok then
		error(result, 0)
	end

	return result
end

local function call_with_owner(owner, func, ...)
	local previous = _spawn_owner

	_spawn_owner = owner

	local ok, result = pcall(func, ...)

	_spawn_owner = previous

	if not ok then
		error(result, 0)
	end

	return result
end

mod:hook(CLASS.PlayerUnitFxExtension, "_create_particles_wrapper", function(func, self, ...)
	return call_with_owner(player_category(self._unit), func, self, ...)
end)

mod:hook(CLASS.PlayerUnitFxExtension, "_add_moving_vfx", function(func, self, ...)
	return call_with_owner(player_category(self._unit), func, self, ...)
end)

mod:hook(CLASS.FxSystem, "play_impact_fx", function(func, self, impact_fx, hit_position, attack_direction, source_parameters, attacking_unit, ...)
	return call_with_owner(category_of_unit(attacking_unit), func, self, impact_fx, hit_position, attack_direction, source_parameters, attacking_unit, ...)
end)

mod:hook(CLASS.FxSystem, "play_surface_impact_fx", function(func, self, hit_position, hit_direction, source_parameters, attacking_unit, ...)
	return call_with_owner(category_of_unit(attacking_unit), func, self, hit_position, hit_direction, source_parameters, attacking_unit, ...)
end)

mod:hook(CLASS.FxSystem, "play_shotshell_surface_impact_fx", function(func, self, fire_position, hit_positions, hit_normals, source_parameters, attacking_unit, ...)
	return call_with_owner(category_of_unit(attacking_unit), func, self, fire_position, hit_positions, hit_normals, source_parameters, attacking_unit, ...)
end)

local SLOT_SCRIPT_ENTRY_POINTS = { "update", "fixed_update", "post_update", "update_unit_position" }

mod:hook_require("scripts/extension_systems/visual_loadout/utilities/wieldable_slot_scripts", function(WieldableSlotScripts)
	for i = 1, #SLOT_SCRIPT_ENTRY_POINTS do
		local entry_point = SLOT_SCRIPT_ENTRY_POINTS[i]

		if WieldableSlotScripts[entry_point] then
			mod:hook(WieldableSlotScripts, entry_point, function(func, wieldable_slot_scripts, unit, ...)
				return call_with_owner(player_category(unit), func, wieldable_slot_scripts, unit, ...)
			end)
		end
	end
end)

local function flamer_set(self)
	return self._weapon_actions.action_shoot_flame and "staff" or "flamer"
end

local function flamer_profile(self)
	local fx_extension = self._fx_extension

	return profile_for(flamer_set(self), player_category(fx_extension and fx_extension._unit))
end

mod:hook(CLASS.FlamerGasEffects, "_update_impact_effects", function(func, self, dt, t)
	local profile = flamer_profile(self)

	if not profile then
		return func(self, dt, t)
	end

	_spawn_context[flamer_set(self) == "staff" and STAFF_IMPACT_EFFECT or FLAMER_IMPACT_EFFECT] = profile
	_spawn_context_active = true

	return call_with_spawn_context(func, self, dt, t)
end)

local _hidden_streams = setmetatable({}, { __mode = "k" })

local function hide_stream(owner, world, stream_effect_id)
	if _hidden_streams[owner] ~= stream_effect_id then
		World_stop_spawning_particles(world, stream_effect_id)

		_hidden_streams[owner] = stream_effect_id
	end
end

mod:hook_safe(CLASS.FlamerGasEffects, "_update_effects", function(self, dt, t)
	local stream_effect_id = self._stream_effect_id

	if not stream_effect_id then
		_hidden_streams[self] = nil
	end

	local profile = flamer_profile(self)

	if not profile then
		return
	end

	local world = self._world

	if profile.mode == "hidden" then
		if stream_effect_id then
			hide_stream(self, world, stream_effect_id)
		end

		return
	end

	if not profile.show or profile.mode == "stock" then
		return
	end

	local value = encoded_value(profile, t)

	if stream_effect_id then
		tint(world, stream_effect_id, value)
	end

	local stopped = self._stoped_particles

	for i = 1, #stopped do
		tint(world, stopped[i], value)
	end
end)

local AilmentSettings = require("scripts/settings/ailments/ailment_settings")
local Ailment = require("scripts/utilities/ailment")
local SOULBLAZE_BUFF = "warp_fire"
local SOULBLAZE_AILMENT = AilmentSettings.effects.warpfire
local FLAMER_BURN_BUFF = "flamer_assault"
local FLAMER_BURN_AILMENT = AilmentSettings.effects.burning
local BURN_TIMING_VARIABLE = "offset_time_duration"
local BURN_UNPATCHED_BREED_PATTERNS = { "daemonhost" }
local BURN_HUE_STEPS = 256
local BURN_SATURATION_STEP = 4096
local BURN_CODE_SCALE = 4
local _burn_starts = setmetatable({}, { __mode = "k" })

mod:hook_safe(Ailment, "play_ailment_effect_template", function(unit, ailment_effect, optional_include_children, optional_custom_duration, optional_custom_offset_time)
	if (ailment_effect ~= SOULBLAZE_AILMENT and ailment_effect ~= FLAMER_BURN_AILMENT) or not unit or not Unit.alive(unit) then
		return
	end

	local template = AilmentSettings.effect_templates[ailment_effect]

	_burn_starts[unit] = {
		start = World.time(Unit.world(unit)),
		offset = optional_custom_offset_time or template.offset_time,
		duration = optional_custom_duration or template.duration,
	}
end)

local function burn_patched(unit)
	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data and unit_data:breed()
	local breed_name = breed and breed.name

	if not breed_name then
		return false
	end

	for i = 1, #BURN_UNPATCHED_BREED_PATTERNS do
		if string.find(breed_name, BURN_UNPATCHED_BREED_PATTERNS[i], 1, true) then
			return false
		end
	end

	return true
end

local function burn_code(profile, t)
	local hue = profile.hue
	local saturation = profile.saturation

	if profile.mode == "rainbow" then
		local phase = t * RAINBOW_CYCLES_PER_SECOND

		hue = phase - math_floor(phase)
		saturation = 1
	end

	local hue_step = math_floor(hue * BURN_HUE_STEPS) % BURN_HUE_STEPS
	local saturation_step = math_floor(saturation * SATURATION_STEPS + 0.5)
	local brightness_step = math_max(MIN_BRIGHTNESS_STEP, math_min(MAX_BRIGHTNESS_STEP, math_floor(profile.brightness + 0.5)))

	return saturation_step * BURN_SATURATION_STEP + hue_step * 16 + brightness_step
end

local SOULBLAZE_FLAME = "content/fx/particles/enemies/buff_warpfire"
local SOUL_PACKAGE_REFERENCE = "Polychromatic"
local _soul_load_ids = rawget(_G, "__polychromatic_soul_packages") or {}

rawset(_G, "__polychromatic_soul_packages", _soul_load_ids)
local _soul_slots_ready = false

local function load_soul_slots()
	for i = 1, #SOUL_SLOTS do
		local slot = SOUL_SLOTS[i]

		if slot.usable then
			if not _soul_load_ids[slot.package] then
				_soul_load_ids[slot.package] = Managers.package:load(slot.package, SOUL_PACKAGE_REFERENCE, nil, true)
			end
		end
	end
end

local _soul_load_warned = false

local function soul_slots_ready()
	if _soul_slots_ready then
		return true
	end

	if next(_soul_load_ids) == nil then
		if not _soul_load_warned then
			_soul_load_warned = true
			mod:info("soulblaze flames: no slot packages loaded, flames stay stock")
		end

		return false
	end

	for _, id in pairs(_soul_load_ids) do
		if not Managers.package:has_loaded_id(id) then
			return false
		end
	end

	_soul_slots_ready = true

	return true
end

local function soul_slot_for(profile, t)
	local hue = profile.hue or 0

	if profile.mode == "rainbow" then
		local phase = t * RAINBOW_CYCLES_PER_SECOND

		hue = phase - math_floor(phase)
	end

	local slot = SOUL_SLOTS[math_floor(hue * #SOUL_SLOTS + 0.5) % #SOUL_SLOTS + 1]

	return slot.usable and slot or nil
end

local SOUL_SWAP_DELAY_FRAMES = 2
local _pending_soul_swaps = {}
local _pending_soul_attach = {}
local SOUL_ATTACH_FRAMES = 2

local function swap_soulblaze_flame(extension, unit, profile, t)
	if not soul_slots_ready() then
		return
	end

	local slot = soul_slot_for(profile, t)

	if slot then
		_pending_soul_swaps[#_pending_soul_swaps + 1] = { extension = extension, unit = unit, slot = slot, wait = SOUL_SWAP_DELAY_FRAMES }
	end
end

local function apply_soul_swap(entry)
	local extension, unit = entry.extension, entry.unit

	if not Unit.alive(unit) then
		return
	end

	local context = extension._buff_context
	local world = context and context.world
	local node_effects = extension._vfx_node_effects

	if not world or not node_effects then
		return
	end

	for _, per_node in pairs(node_effects) do
		local data = per_node[SOULBLAZE_FLAME]

		if data and data.particle_id then
			World.destroy_particles(world, data.particle_id)

			local particle_id = World.create_particles(world, entry.slot.package, Unit.world_position(unit, 1))

			World.set_particles_surface_effect(world, particle_id, unit, nil, nil, true)

			data.particle_id = particle_id
			_pending_soul_attach[#_pending_soul_attach + 1] = { world = world, unit = unit, particle_id = particle_id, wait = SOUL_ATTACH_FRAMES }
		end
	end
end

local function run_pending_soul_attach()
	local waiting = {}

	for i = 1, #_pending_soul_attach do
		local entry = _pending_soul_attach[i]

		entry.wait = entry.wait - 1

		if entry.wait > 0 then
			waiting[#waiting + 1] = entry
		elseif Unit.alive(entry.unit) and World.are_particles_playing(entry.world, entry.particle_id) then
			World.set_particles_surface_effect(entry.world, entry.particle_id, entry.unit, nil, nil, true)
		end
	end

	_pending_soul_attach = waiting
end

local function run_pending_soul_swaps()
	local waiting = {}

	for i = 1, #_pending_soul_swaps do
		local entry = _pending_soul_swaps[i]

		entry.wait = entry.wait - 1

		if entry.wait > 0 then
			waiting[#waiting + 1] = entry
		else
			apply_soul_swap(entry)
		end
	end

	_pending_soul_swaps = waiting
end

local function clear_pending_soul_swaps()
	_pending_soul_swaps = {}
	_pending_soul_attach = {}
end

local function skull_is_mine(skull_unit)
	local player_unit = local_player_unit()
	local spawner = player_unit and ScriptUnit.has_extension(player_unit, "companion_spawner_system")
	local units = spawner and spawner:companion_units()

	if not units then
		return false
	end

	for i = 1, #units do
		if units[i] == skull_unit then
			return true
		end
	end

	return false
end

local SKULL_ARCHETYPE = "cryptic"

local SKULL_BREED_PATTERN = "servo_skull"

local function burn_set_for(owner_unit)
	if not owner_unit then
		return nil
	end

	local spawn_manager = Managers.state.player_unit_spawn
	local player = spawn_manager and spawn_manager:owner(owner_unit)

	if player then
		if player:archetype_name() == SKULL_ARCHETYPE then
			return _skull_burn_enabled and "skull" or nil
		end

		return _flamer_burn_enabled and "flamer" or nil
	end

	local unit_data = ScriptUnit.has_extension(owner_unit, "unit_data_system")
	local breed = unit_data and unit_data.breed and unit_data:breed()
	local breed_name = breed and breed.name

	if breed_name and string.find(breed_name, SKULL_BREED_PATTERN, 1, true) then
		return _skull_burn_enabled and "skull" or nil
	end

	return _flamer_burn_enabled and "flamer" or nil
end

local function flamer_burn_profile_for(template_name, owner_unit)
	if template_name ~= FLAMER_BURN_BUFF then
		return nil
	end

	local set_id = burn_set_for(owner_unit)
	local category = category_of_unit(owner_unit)

	if set_id == "skull" and category ~= "mine" then
		local spawn_manager = Managers.state.player_unit_spawn
		local player = spawn_manager and spawn_manager:owner(owner_unit)
		local local_player = Managers.player:local_player_safe(1)

		category = ((player and player == local_player) or skull_is_mine(owner_unit)) and "mine" or "team"
	end

	local profile = set_id and profile_for(set_id, category)

	if not profile or not profile.show or profile.mode == "stock" or profile.mode == "hidden" then
		return nil
	end

	return profile
end

local function flamer_burn_profile(buff_instance)
	return flamer_burn_profile_for(buff_instance:template().name, buff_instance:owner_unit())
end

local function flamer_burn_added(self, buff_instance)
	local profile = flamer_burn_profile(buff_instance)
	local unit = self._unit

	if not profile or not unit then
		return
	end

	local timing = _burn_starts[unit]

	_burn_starts[unit] = nil

	if not Unit.alive(unit) then
		return
	end

	local t = gameplay_time()

	if not timing or not _burn_patch_served or not burn_patched(unit) then
		return
	end

	local code = burn_code(profile, t)

	Unit.set_vector3_for_materials(unit, BURN_TIMING_VARIABLE, Vector3(BURN_CODE_SCALE * code + timing.offset, timing.start, timing.duration), true)
end

local function call_with_burn_context(profile, func, ...)
	if not profile then
		return func(...)
	end

	for effect_name in pairs(BURN_PALETTES) do
		_spawn_context[effect_name] = profile
	end

	_spawn_context_active = true

	return call_with_spawn_context(func, ...)
end

local function burn_owner_from_args(...)
	for i = 1, select("#", ...), 2 do
		if select(i, ...) == "owner_unit" then
			return (select(i + 1, ...))
		end
	end

	return nil
end

mod:hook(CLASS.MinionBuffExtension, "_add_buff", function(func, self, template, t, from_server_correction, ...)
	local profile = flamer_burn_profile_for(template and template.name, burn_owner_from_args(...))

	return call_with_burn_context(profile, func, self, template, t, from_server_correction, ...)
end)

mod:hook(CLASS.MinionBuffExtension, "_on_add_buff", function(func, self, buff_instance)
	func(self, buff_instance)
	flamer_burn_added(self, buff_instance)

	if not _soulblaze_enabled or buff_instance:template().name ~= SOULBLAZE_BUFF then
		return
	end

	local unit = self._unit

	if not unit then
		return
	end

	local timing = _burn_starts[unit]

	_burn_starts[unit] = nil

	if not Unit.alive(unit) then
		return
	end

	local profile = profile_for("staff", category_of_unit(buff_instance:owner_unit()))

	if not profile or not profile.show or profile.mode == "stock" then
		return
	end

	local t = gameplay_time()

	swap_soulblaze_flame(self, unit, profile, t)

	if not timing or not _burn_patch_served or not burn_patched(unit) then
		return
	end

	local code = burn_code(profile, t)

	Unit.set_vector3_for_materials(unit, BURN_TIMING_VARIABLE, Vector3(BURN_CODE_SCALE * code + timing.offset, timing.start, timing.duration), true)
end)

local servo_skull_flamer = require("scripts/settings/fx/effect_templates/companion_servo_skull_flamer")

mod:hook_safe(servo_skull_flamer, "update", function(template_data, template_context, dt, t)
	local stream_effect_id = template_data.stream_effect_id

	if not stream_effect_id then
		_hidden_streams[template_data] = nil

		return
	end

	local profile = profile_for("skull", skull_is_mine(template_data.unit) and "mine" or "team")

	if not profile then
		return
	end

	if profile.mode == "hidden" then
		hide_stream(template_data, template_context.world, stream_effect_id)

		return
	end

	if not profile.show or profile.mode == "stock" then
		return
	end

	tint(template_context.world, stream_effect_id, encoded_value(profile, t))
end)

mod.update = function()
	if _pending_tints[1] then
		retry_pending_tints()
	end

	if _pending_soul_swaps[1] then
		run_pending_soul_swaps()
	end

	if _pending_soul_attach[1] then
		run_pending_soul_attach()
	end
end

mod.on_game_state_changed = function(status, state_name)
	local gameplay_init = state_name == "GameplayStateRun"
		or string.sub(state_name or "", 1, 12) == "GameplayInit"

	if status == "enter" then
		_gameplay_running = state_name == "GameplayStateRun"
	elseif state_name == "StateGameplay" or state_name == "GameplayStateRun" then
		_gameplay_running = false
	end

	if not gameplay_init then
		clear_pending_tints()
		clear_pending_soul_swaps()
	end

	if state_name == "StateGameplay" and status == "enter" then
		load_soul_slots()
		load_glow_slots()
		pin_extended_packages()
	end
end


mod.on_setting_changed = function()
	cache_settings()
end

mod.on_settings_reset = function()
	cache_settings()
end

cache_settings()

mod.on_all_mods_loaded = function()
	mod:info("Polychromatic %s loaded", tostring(mod.version))

	local ui = Managers.ui
	local in_level = ui ~= nil and ui:get_current_sub_state_name() == "GameplayStateRun"

	_gameplay_running = in_level

	if not asset_redirect then
		return
	end

	asset_redirect.commit()

	local served = 0
	local restart = false

	for i = 1, #_redirect_handles do
		local state = asset_redirect.state(_redirect_handles[i])

		if redirect_served(state) then
			served = served + 1
		else
			mod:info("redirect %s: %s", REDIRECTS[i].stock, state)
		end

		restart = restart or state == "restart_required"
	end

	mod:info("redirects served: %d of %d", served, #_redirect_handles)

	local burn_entries, burn_served = 0, 0

	for i = 1, #REDIRECTS do
		if string.find(REDIRECTS[i].file, "%.burnhsv$") then
			local state = asset_redirect.state(_redirect_handles[i])

			burn_entries = burn_entries + 1

			if redirect_served(state) then
				burn_served = burn_served + 1
			end
		end
	end

	_burn_patch_served = burn_entries > 0 and burn_served == burn_entries

	mod:info("burn shader patch served: %s", tostring(_burn_patch_served))

	local soul_usable = 0

	for i = 1, #SOUL_SLOTS do
		local slot = SOUL_SLOTS[i]

		slot.usable = redirect_served(asset_redirect.state(_redirect_handles[slot.bundle_redirect])) and redirect_served(asset_redirect.state(_redirect_handles[slot.material_redirect]))

		if slot.usable then
			soul_usable = soul_usable + 1
		end
	end

	mod:info("soulblaze flame slots usable: %d of %d", soul_usable, #SOUL_SLOTS)

	local glow_usable, glow_total = 0, 0

	for _, list in pairs(GLOW_SLOTS) do
		for i = 1, #list do
			local slot = list[i]
			local bundle_ok, material_ok = false, false

			for k = 1, #REDIRECTS do
				if REDIRECTS[k].stock == slot.bundle then
					bundle_ok = redirect_served(asset_redirect.state(_redirect_handles[k]))
				elseif REDIRECTS[k].stock == slot.virtual_path then
					material_ok = redirect_served(asset_redirect.state(_redirect_handles[k]))
				end
			end

			slot.usable = bundle_ok and material_ok
			glow_total = glow_total + 1

			if slot.usable then
				glow_usable = glow_usable + 1
			end
		end
	end

	mod:info("las glow slots usable: %d of %d", glow_usable, glow_total)

	if in_level then
		load_soul_slots()
		load_glow_slots()
		pin_extended_packages()
	end

	if restart then
		mod:echo(mod:localize("restart_required"))
	end
end
