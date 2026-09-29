--[[
	Name: Polychromatic
	Author: Wobin
	Date: 29/09/2026
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
		sha256 = "2b45ac00f235a83c3b60e94bad023b22575145c1af0613f535cfcf3068e555ee",
	},
	{
		stock = "data/85/85d24accc98ef272",
		file = "85d24accc98ef272.livehsv2",
		sha256 = "1ed35c422ade46b3feb429a7e8607930246e18e5c4084eec6daf13a8b451b1a3",
	},
	{
		stock = "data/03/03f68803faf03b51",
		file = "03f68803faf03b51.livehsv",
		sha256 = "60eafe2a5921d495b974f794467ccb17037d17172b60d63b0cac7c9a3abeaa0e",
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
		sha256 = "aca054e4d0ff6be20a0ffc13c4c60b80fbd25d99a0af20547ad7a340e0136503",
	},
	{
		stock = "data/ae/ae9963d8c98fe6b6",
		file = "ae9963d8c98fe6b6.livehsv",
		sha256 = "542881aa3fe75bdc20c2d3a6a77da28c34d9991d4ee51e8d89266e5adec74769",
	},
	{
		stock = "data/18/186941c392bb5d7b",
		file = "186941c392bb5d7b.livehsv",
		sha256 = "ab40b9991acdad19d41527ad2dfba869521893f8541c09f59276f707d0f9ce80",
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
		sha256 = "95c3e1172e77958d3ce823f3528ef8f9cc8d8ad375a8dc176826613725bbc95e",
	},
	{
		stock = "data/15/150a4ba090c95379",
		file = "5b86a311c0ac5cf0.livehsv",
		sha256 = "c70c8646803d8adcbf7e9620a8393ed763de8f98dc78cfd56234de33f5358cd7",
	},
	{
		stock = "data/19/19bcec6ae1991184",
		file = "3586b12003ab11fc.livehsv",
		sha256 = "3bfa6308dfc6cd34dd74000f427b7967391636c71092cc7a0e043e3912dcc8b7",
	},
	{
		stock = "data/6b/6bcf952c725f6a2f",
		file = "6bcf952c725f6a2f.livehsv",
		sha256 = "75d438d8b9a5cd4c0f91c74f51a6bf553482b4ab3fc931fa22bd7adb66b217a0",
	},
	{
		stock = "28d55df9efb7f8e5",
		file = "28d55df9efb7f8e5.pyro",
		sha256 = "6dc3d1bc3fa65afd02b1b965d419d37a3d3978cd078f2fda3de263c849ba072e",
	},
	{
		stock = "30ebeee18093c079",
		file = "30ebeee18093c079.pyro",
		sha256 = "bb54dffaa14cb6aff4fd777645e6847b8f338d9e3304f67646b2ca082f81e7be",
	},
	{
		stock = "data/bb/bb79ba7a5b92d132",
		file = "bb79ba7a5b92d132.livehsv",
		sha256 = "0791ebee80d406e27e850c8974b0e5c7d4c4453d421de9cda8b3af52ea7e5509",
	},
	{
		stock = "data/af/af395bb3270f316d",
		file = "af395bb3270f316d.livehsv",
		sha256 = "f347c86781249ebbcf2b793c75f474ee55789d5c3340776c24efd2598ffd6ed7",
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
		sha256 = "9718ee668c306c2a0ecad99fa4a7f904af6ee52b478cec288532e02f0c4a2840",
	},
	{
		stock = "data/3c/3c5cb0cf7d5047c8",
		file = "3c5cb0cf7d5047c8.livehsv",
		sha256 = "5d984ef47001416ffe70b0fcd4d8f06500ec9177215e093d5c82f1142122245d",
	},
	{
		stock = "data/61/61446d60d543f9db",
		file = "61446d60d543f9db.livehsv",
		sha256 = "e4d4083ca343bb837ea02b49a75b5338b0cd126a8a2aafa7e873863fec8f91fd",
	},
	{
		stock = "data/70/7082301abe176951",
		file = "7082301abe176951.livehsv",
		sha256 = "889eee0183a9676c837c60b7248e070c506a983b5ac80c75152ec2c37045fed6",
	},
	{
		stock = "data/94/943d1b280637fc01",
		file = "943d1b280637fc01.livehsv",
		sha256 = "46b846d2261aa4dd0b68cb6c3de9ca5d57a8c7f6fb011d3eee740559bce08fcc",
	},
	{
		stock = "data/95/953a43ee8c53c708",
		file = "953a43ee8c53c708.livehsv",
		sha256 = "f86ec47dc0061cb87bee02e4dab1c9e351ae6ff7fd40d86b0c763b06802ace3a",
	},
	{
		stock = "data/ae/aeac9afc8d4df9bb",
		file = "99ff58cc04799e02.livehsv",
		sha256 = "d373c16beb557c909492a710296a1375ff644913b3235718c7e49f23559b36c0",
	},
	{
		stock = "5dc0d564aae47b93",
		file = "5dc0d564aae47b93.pyro",
		sha256 = "470c3604d6b9db8db3f5c4571aeb1ca40aa9400c7d92815897a991108334a24d",
	},
	{
		stock = "data/70/70874be43492180f",
		file = "70874be43492180f.livehsv",
		sha256 = "985afcbb39fd1c4b79c70ef085f0068519e3e892be199b5f2026cf35c80b7c97",
	},
	{
		stock = "data/ac/acfde9cb5522d20e",
		file = "5b86a311c0ac5cf0.livehsv",
		sha256 = "2eb22f231425289e91d021a6b47f3137d1fac055e902d26d52cafd54d9199513",
	},
	{
		stock = "data/b6/b6fb4f31823ffdae",
		file = "2ac35fee97857b92.livehsv",
		sha256 = "818ecdcde59c08b56d13054c6c20f76edd87b227b37bf2589000698543be59fe",
	},
	{
		stock = "data/09/0937ecdd02b49a51",
		file = "0937ecdd02b49a51.glowmat",
		sha256 = "d1bc872f037612863178360e84382b8600ab4323e4636fa6917e0606f21d38cc",
	},
	{
		stock = "data/38/389635690311f44d",
		file = "389635690311f44d.livehsv",
		sha256 = "a4c31ec63a06de2541efa550296303dd9e2e06b70ca070f5896194f4f303cdfe",
	},
	{
		stock = "data/35/35978c7053a8aafc",
		file = "35978c7053a8aafc.livehsv",
		sha256 = "be4f5777f2e9e368383d14898e623f813e473476e1382f65a6f893a311ed7544",
	},
	{
		stock = "data/70/707cdbdd606c30cd",
		file = "ace5d2aa548b1ba8.livehsv",
		sha256 = "bc2759865a3bedbf83e166df051b8795b84fdfef078dd9b1490ebe18d01defff",
	},
	{
		stock = "data/9b/9b10dd963027a9b2",
		file = "7082301abe176951.impactglow",
		sha256 = "976ef83537062a6b74854f359abd0882d249e3bc7c203bf07a81ed0d91b6f09b",
	},
	{
		stock = "data/4f/4f3403e5378fc65d",
		file = "4f3403e5378fc65d.parentswap",
		sha256 = "a1cab756e0f73c0a3a1ce4347b2ea77c1f01f518cee4c2236be6fdf4bbb58da0",
	},
	{
		stock = "data/d4/d436973b399d0f0f",
		file = "af6345509d7beaa3.parentswap",
		sha256 = "7d61ad6389b0f1098f3bf79584bc889d37384c9fa08516365622b852c9e14fde",
	},
	{
		stock = "data/50/501fc3a18853b87e",
		file = "27c0cb428a261dc8.livehsv",
		sha256 = "b9984ae8c39aaa4fdc16f50f14d75666b7576301ea97882419c453a4d2861ce9",
	},
	{
		stock = "data/a0/a05cac4ba1830c52",
		file = "a05cac4ba1830c52.livehsv",
		sha256 = "98fe876900735c06df7bef2822e5dc3e35efedcaf234edfdc484ecedeb03efdb",
	},
	{
		stock = "data/b6/b674173297823523",
		file = "b674173297823523.livehsv",
		sha256 = "fd245d6d4fd71cef20675318ee7e1db5c7d38dbbfdcf245936e45266c3755bc1",
	},
	{
		stock = "data/c7/c77100b7e03c017e",
		file = "c77100b7e03c017e.livehsv",
		sha256 = "de1c595f88ad89f9803f23c113a922e797191ccf8adc2bdbea55c8e1a00445fc",
	},
	{
		stock = "data/c9/c9a22ea5418d46c4",
		file = "c9a22ea5418d46c4.livehsv",
		sha256 = "2a67e10161ebb6f212a27f8bb571a43aebfd250094b0c598db7bfc9e0554e951",
	},
	{
		stock = "data/d5/d59ba29afc0927bb",
		file = "d59ba29afc0927bb.livehsv",
		sha256 = "934380520edb2bae95849c5c7a608caa8d60094e27732cb2b266e24f2d5bd490",
	},
	{
		stock = "data/eb/eb6d4860ae6b197a",
		file = "eb6d4860ae6b197a.livehsv",
		sha256 = "74da2f36f548d0f2bc1d2e2cc858788ceffbd6b27eabc56d19dad8ac9b103e3e",
	},
	{
		stock = "data/ee/eed5a626643585ec",
		file = "eed5a626643585ec.livehsv",
		sha256 = "8a934e520a25b7f02a5eb9d940f8f013b70af6f94830cac6e13561d01b4f7c1e",
	},
	{
		stock = "data/f8/f88272fabfa9807e",
		file = "f88272fabfa9807e.livehsv",
		sha256 = "d362cc3af95b5eb991aa3e99f0d35b179f22a97057fd19a0727a77c48fe1f422",
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
		sha256 = "a0fd9d9aedfda85fed1306af1d98b34fbb65eacf10470023af49c24db977794d",
	},
	{
		stock = "data/b5/b568acd1f3be5206",
		file = "b568acd1f3be5206.livehsv",
		sha256 = "7eb56c4674142c66b350956b865a575dd70a8af5a5b21976b282af28249b5281",
	},
	{
		stock = "data/2e/2e84f67cb43e161e",
		file = "2e84f67cb43e161e.livehsv",
		sha256 = "72070545d05baa3097dac324e946ea3ab6468db6fff94ad3f396a4d04b747729",
	},
	{
		stock = "data/9c/9c6892714be719be",
		file = "9c6892714be719be.livehsv",
		sha256 = "e10c1616f51a8aabcb7586f344f01265276c02d5466986f986f9f85f7c3bec94",
	},
	{
		stock = "data/73/731949c698805166",
		file = "731949c698805166.livehsv",
		sha256 = "1638e47d71c742e66761a8541442b3a9e226c03959e56b9422b27169d6fb12e2",
	},
	{
		stock = "data/e6/e698932c695e72d7",
		file = "e698932c695e72d7.livehsv",
		sha256 = "8e1ffdbb56de48de926aced13d234d6c498570b6ebd9b2c025c7631dae7d690b",
	},
	{
		stock = "data/5f/5f599134bd6cb4d7",
		file = "5f599134bd6cb4d7.livehsv",
		sha256 = "558d3262e3e3e7324f361caeaa50a346352cae3dfac33aaf9c6d2df73e38cca8",
	},
	{
		stock = "data/18/18c49d3c8a5beffb",
		file = "18c49d3c8a5beffb.livehsv",
		sha256 = "91bdfa25f0050bea6c24fd60e8b592294652c6a129ae6349915d4af472e43233",
	},
	{
		stock = "data/b3/b3b02753bc5c5eb6",
		file = "b3b02753bc5c5eb6.livehsv",
		sha256 = "bb33340b9d9b191b6f274652a9764f5ea61606efebc72a53a3a3a9afec854711",
	},
	{
		stock = "data/90/908e498779039c2f",
		file = "908e498779039c2f.livehsv",
		sha256 = "1739a64f5e5906d1d759cac9d359b028d4ae78f6e15c71b6f308fea45268093c",
	},
	{
		stock = "data/3d/3d61898424cd2d53",
		file = "3d61898424cd2d53.livehsv",
		sha256 = "1862f7c2280efb9f92dffae092547f67e7d023c1ccdefd01c9b0b2ec9ce01b58",
	},
	{
		stock = "data/71/71c11a9ab38ccef6",
		file = "71c11a9ab38ccef6.livehsv",
		sha256 = "1c8e1c90c4ff7505234ef6fd17f94465d13852e28de6dcdd7908e6542c127769",
	},
	{
		stock = "data/d4/d44c3e55524792c0",
		file = "d44c3e55524792c0.livehsv",
		sha256 = "934659d06f9229120d3fad8987f9f2459440354d62cc4dd5cdb7661a7f30bad1",
	},
	{
		stock = "data/2c/2cf5a90222f0f675",
		file = "2cf5a90222f0f675.livehsv",
		sha256 = "a42b238ffba4c0d5e61eeb5b76f71210744b6d30979cf1499d042fab0d7ffb15",
	},
	{
		stock = "data/ed/edd0c83a7ed3d834",
		file = "edd0c83a7ed3d834.livehsv",
		sha256 = "c525935a912bb1130f39bb752dc1bc0dfeb644328d4255b3e4e5ac67763a19f2",
	},
	{
		stock = "data/51/51594febc2f498b9",
		file = "51594febc2f498b9.livehsv",
		sha256 = "c3eb16be4316eda2f30167ae4f0461c954d4942fb1bb2ec225a84924d6d40301",
	},
	{
		stock = "data/51/51be2b7e18d16f85",
		file = "51be2b7e18d16f85.livehsv",
		sha256 = "7917ef025cc3807ceb2e48d40ae59cf06ee9a07b3e9b36daa43ad41da35dba9c",
	},
	{
		stock = "data/96/9648f7e733af27de",
		file = "9648f7e733af27de.livehsv",
		sha256 = "fe3a4c6668e08ff22f2d8f4245240b289a26bf3cbc4e9156484b36270d683437",
	},
	{
		stock = "data/1b/1b59d000e1b00a00",
		file = "1b59d000e1b00a00.livehsv",
		sha256 = "8ff9eeff0521c79c7e89b9cdcfbff7b9fe32a3cee51a29137244e0ef888da78e",
	},
	{
		stock = "data/7b/7b5f45d570446038",
		file = "7b5f45d570446038.livehsv",
		sha256 = "96eb3a66f4143c13d6bee2929bcfe83e68ec4ad3887751d1e56e0b1dc9ef84ba",
	},
	{
		stock = "data/3e/3e7d35923677ce5b",
		file = "3e7d35923677ce5b.livehsv",
		sha256 = "892a423ddda8e8a098e488239c3d8aad8b37d772663fc8cfb8c28043d7259b03",
	},
	{
		stock = "data/c2/c29d268a1116d6c8",
		file = "c29d268a1116d6c8.livehsv",
		sha256 = "9d59c935e2baceccc8ebc147fa84dbbe51d9ba29d940d6ea3f813a6b3cbfe707",
	},
	{
		stock = "data/33/3336d5d7ab5ea336",
		file = "3336d5d7ab5ea336.livehsv",
		sha256 = "f1ee18f6b1e56652e2481fc79fe0db0c48fbf91a387424ebe6efaa56735e7551",
	},
	{
		stock = "data/bf/bf4522e91fe81307",
		file = "bf4522e91fe81307.livehsv",
		sha256 = "f3046474a1836ec4e4374db3f6c9672ff0d663251d3d17a81044ade019609eeb",
	},
	{
		stock = "data/94/947f9d05243c5c05",
		file = "947f9d05243c5c05.livehsv",
		sha256 = "0527ce9ca8ef87827cf16d0ba61b9eb7e929c7a8d78f85bb04e44185b4e7c92f",
	},
	{
		stock = "data/e2/e28e22d29032ef7f",
		file = "e28e22d29032ef7f.livehsv",
		sha256 = "66fd6c30dafb57e29076083068d570e17ce8b861ca3bad0a1e9c8a8ea79be007",
	},
	{
		stock = "data/23/23fef9dc3db476e5",
		file = "23fef9dc3db476e5.livehsv",
		sha256 = "678b4e401d252491d55e8cf69961ee352ee0836d7d220d484d6b34d4c53e85a7",
	},
	{
		stock = "data/5b/5bb5ef9851943876",
		file = "5bb5ef9851943876.livehsv",
		sha256 = "49e1e91d5c58d07cef605b52614b13d6a88df0edb24e755ae5159ff363086963",
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
		sha256 = "8fd1b84bf3ffd75a1e1a47a40b81c7ca1233b371822169b670256bf10b2efd30",
	},
	{
		stock = "data/3c/3c2bb28d1f2b943b",
		file = "3c2bb28d1f2b943b.livehsv",
		sha256 = "bf6390980da01d26443af6693805cc5455c347561d4ce4649da0377971d09553",
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
		sha256 = "9c6c3a104e72269af4e86721539c428a0ce28c8a0e18546735e2001b108696ae",
	},
	{
		stock = "data/cb/cb1759794495e9e3",
		file = "cb1759794495e9e3.livehsv",
		sha256 = "765dee2d51a23cd1aff0ca0276158e876843b96eb64d4a2f7e1d6d3f07670e4c",
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
		sha256 = "8377f015fbc4c9148114e77bbceb8b3e7a459d37e3df3ab5e08195f2c734ef4d",
	},
	{
		stock = "data/60/607dbb4a57138f8d",
		file = "607dbb4a57138f8d.livehsv",
		sha256 = "9e0657d90958670b552f169281390a24a77903802d3d75c401d38860c1e3db2e",
	},
	{
		stock = "data/3d/3d0cb1d8ae277e71",
		file = "3d0cb1d8ae277e71.livehsv",
		sha256 = "1dd227c9d54371ddf42e6d76b76f275df592375f552bfcb15c87e652df6c2156",
	},
	{
		stock = "data/2c/2c867be4918ccc18",
		file = "2c867be4918ccc18.livehsv",
		sha256 = "f3e7a25f8be60fb5991736af9e27e31739716d467f99e578fd2652edd3473347",
	},
	{
		stock = "data/18/18f92705d5855677",
		file = "18f92705d5855677.livehsv",
		sha256 = "1a1543a6f9b43358c8d2d86b75f1824de10c03ffefbbf663d0305dbba2f95066",
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
		sha256 = "d2cad05bf917a93a92be6ca764f41578fdb273cbe330d66dc8fb74be20bb7f78",
	},
	{
		stock = "data/4f/4f3c20108df32ff2",
		file = "4f3c20108df32ff2.burnhsv",
		sha256 = "abb2900b79dae56c64470471e12c73a7393d3bb405bf293328e5705cf98d13e4",
	},
	{
		stock = "data/ad/ade3d7d830f2254a",
		file = "ade3d7d830f2254a.burnhsv",
		sha256 = "9b89b6b7a8cf1c4f75414e36e2553500bdcd2bd973fc1b3763c4c9ba163bfc34",
	},
	{
		stock = "data/eb/eb09dd77efe06a9d",
		file = "eb09dd77efe06a9d.burnhsv",
		sha256 = "cdbe7ae84155819f4c10e69104c3171294a8e31f63b5c1fa921c4fc2c2c66a5b",
	},
	{
		stock = "data/2d/2d197c488c9bebc2",
		file = "2d197c488c9bebc2.burnhsv",
		sha256 = "8f4d9da89464916252b0d3e835a0ca6579286c77855fad028b0cab3bb4bdf802",
	},
	{
		stock = "data/35/35ef09cd5356eead",
		file = "35ef09cd5356eead.burnhsv",
		sha256 = "f8ed47bf86a1126d60a1663009378cc026b07dfa327a47b664a1ce2ac3b132b1",
	},
	{
		stock = "data/7f/7f17d42421a43450",
		file = "7f17d42421a43450.burnhsv",
		sha256 = "8e7e780beb2bfc826cf8b151d3b378fc87e5a7d7cef135662e9a107e74de8a96",
	},
	{
		stock = "data/44/4490a3f7f03c1e69",
		file = "4490a3f7f03c1e69.burnhsv",
		sha256 = "dd5c95c040f1595f5f3a5dec8a39763debb5c79979667aa51aeb183597880052",
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
		material_sha256 = "038beb79adb65bb7ec75096b159159ff2699ed794d38e6632d0e0fad66a7a9af",
	},
	{
		package = "content/fx/particles/debug/fx_debug_gpu_fireball_normal",
		bundle = "f0806ea958cf8ff7",
		bundle_sha256 = "1b1ff8645e7927d065b3a35417bb674bd55514746bdb58e5e3615bdfa4738a9d",
		material = "data/da/dacf0e63f7921f7a",
		material_sha256 = "3b6c0a0bd9c7b15a03d2d6ed8b2e71cc18337aecf1dd426d45cf98ac8b4f10fb",
	},
	{
		package = "content/fx/particles/weapons/rifles/ripper_gun/ripper_gun_trail",
		bundle = "2e58389b6ed2142d",
		bundle_sha256 = "5012fb3008acb1f00827c9aeb76463280d5fb1d99b2f013e485936d458d079ce",
		material = "data/3c/3c50f2ff573a08cd",
		material_sha256 = "4bc885f2c9d23bcea7b2a969f6235a82f594a0ca4dc989cd4fa6286bd8e24a34",
	},
	{
		package = "content/fx/particles/impacts/weapons/hammer_impact",
		bundle = "14d5b2c5e9ebee8f",
		bundle_sha256 = "8eddf55f76cd34d5b88b3b44c7e5400a7a58d97464e1ba829183f1852333ba10",
		material = "data/fd/fdf161cab348d473",
		material_sha256 = "5fbe19107e8f9f212654082c5e396e182a809793c7ab9be42dc98ad3c5c32717",
	},
	{
		package = "content/fx/particles/enemies/plague_ogryn_flies",
		bundle = "f608745eeef0699e",
		bundle_sha256 = "f7f5be2a1a0babc98eea173b7b8e59b1698f54405de9a1fc6e50788071634290",
		material = "data/05/0513e621cdd87ad5",
		material_sha256 = "e623907924b5369acd44c09b21521273404f7805460312ffff9df3775634c71b",
	},
	{
		package = "content/fx/particles/enemies/lasgun_beam_assault",
		bundle = "d1b72a7d311e7090",
		bundle_sha256 = "63c42459f77dafa516c7ddc15eb6223b617b7147ab110ee1a2fdc180d97fdfd4",
		material = "data/1a/1a07775aebe7ef0e",
		material_sha256 = "a7d973e7807b57b3c60028d8fd4ffbbefb0bd25f4b652848e9b0f97f4f7f0e0b",
	},
	{
		package = "content/fx/particles/liquid_area/corruptor_nurgle_goo_splatter",
		bundle = "e0f0480393b4255a",
		bundle_sha256 = "674e0bcb8b1b9c25f5aae9c38add454ac7e4600d16ed68dace2d1c8472f50e0d",
		material = "data/f1/f197c21689ca1ef6",
		material_sha256 = "45e49045e102f54625d53765bfe0163a540dcda375c8f80630bfa2808c9943c3",
	},
	{
		package = "content/fx/particles/weapons/rifles/shotgun/combat_shotgun_ogryn_impact_v01",
		bundle = "9d3c4c3582f50f13",
		bundle_sha256 = "9d14be1f9cea237647e375e0847d0089ef1aa9b9beffd358c1a73da5c5153f89",
		material = "data/87/87df9553641534df",
		material_sha256 = "a629ba72bdb84968c6b8ba68a6ef5d32cca25bcd4871e0718c3f61fac3f719d4",
	},
	{
		package = "content/fx/particles/screenspace/screen_ogryn_charge",
		bundle = "80d83c7c23a3464b",
		bundle_sha256 = "6764699f2c10ecdc0930ddd4a926173432215c102778f761a05af9016aa7d14a",
		material = "data/21/21e06c09435b212e",
		material_sha256 = "690a61a83338cf6927d1d214a65ff6c7341c78a49f9d54b5cc25b30165949d1d",
	},
	{
		package = "content/fx/particles/weapons/rifles/zealot_flamer/zealot_flamer_code_control",
		bundle = "4713ab38f46f4f07",
		bundle_sha256 = "3cdc22e667dc8c53a3982c97c105fd69b333f081efa8b7d71e1e58618b4dcc35",
		material = "data/3e/3ecd3bb2d511984e",
		material_sha256 = "cfedf2c4e66783bfecd9c0ed24331b246dbd6556a48ef5aeefba8285ddf78c69",
	},
	{
		package = "content/fx/particles/impacts/weapons/lasgun/lasgun_impact_weakspot",
		bundle = "e3eac989dc018e47",
		bundle_sha256 = "58225a9e98b515a7095908ac811be8d7621f8ea9f7fe8b296fe3637548145e9f",
		material = "data/17/170af2d8a7f30f7b",
		material_sha256 = "8848d8391cd54787db394e91c08350622d92df307acca0de6ec4cd580504b975",
	},
	{
		package = "content/fx/particles/screenspace/screen_zealot_preacher_shield",
		bundle = "84d9e75472d57ebb",
		bundle_sha256 = "4f7a6192442e98fa9572411d158b77d09f7e5f85ca0b4f4531c4b3cf1b8417ca",
		material = "data/75/750c5672dc47d156",
		material_sha256 = "f1783db2dc5671c5952f6a985725d2bf842750be9b937f574c438857aec15287",
	},
}
local baked = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/Polychromatic_bake")({
	mod = mod,
	redirects = REDIRECTS,
	soul_slots = SOUL_SLOTS,
	min_brightness = MIN_BRIGHTNESS_STEP,
	stock_brightness = STOCK_BRIGHTNESS_STEP,
	max_brightness = MAX_BRIGHTNESS_STEP,
})
local SOUL_PAYLOAD_DIR = baked.payload_dir
local GLOW_SLOTS = baked.glow_slots
local GLOW_SOURCE_EFFECTS = baked.glow_source_effects

local asset_redirect = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/asset_redirect")
local _material_format = { expected = 62, probe = "../bundle/data/e9/e90383bc561fd9ae" }

do
	local lua = rawget(_G, "Mods") and Mods.lua
	local lua_io = lua and lua.io
	local file = lua_io and lua_io.open(_material_format.probe, "rb")
	local head = file and file:read(4)

	if file then
		file:close()
	end

	if head and #head == 4 then
		local b1, b2, b3, b4 = string.byte(head, 1, 4)

		_material_format.found = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
	end

	_material_format.ok = _material_format.found == _material_format.expected

	if not _material_format.ok then
		if asset_redirect then
			asset_redirect.clear(mod)
		end

		asset_redirect = nil
	end
end
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

	asset_redirect.commit()
end

local _debug_logging = mod:get("debug_logging") == true
local VARIABLE = "lighting_far_range"
local STOCK_VALUE = 1000
local HUE_STEPS = 1024
local SATURATION_STEPS = 15
local STEPS = {
	code_divisor = 16384,
	pending_tint_frames = 30,
	burn_saturation = 4096,
	soul_swap_delay_frames = 2,
	soul_attach_frames = 2,
}
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
		by_category[set.categories[j]] = { set = set.id, category = set.categories[j], show = true, mode = "stock", hue = 0, saturation = 1, brightness = STOCK_BRIGHTNESS_STEP }
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
	_debug_logging = mod:get("debug_logging") == true
	_soulblaze_enabled = mod:get("soulblaze") ~= false
	_flamer_burn_enabled = mod:get("flamer_burn") ~= false
	_skull_burn_enabled = mod:get("skull_burn") ~= false

	for set_id, by_category in pairs(_profiles) do
		for category, profile in pairs(by_category) do
			local prefix = set_id .. "_" .. category .. "_"

			profile.show = mod:get(prefix .. "show") ~= false
			profile.mode = profile.show and mod:get(prefix .. "mode") or "stock"
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

	return STOCK_VALUE + saturation_step + (hue_step * 16 + brightness_step) / STEPS.code_divisor
end

local _gameplay_running = false

local _cloud_cache = {}

local function tint(world, particle_id, value)
	if not _gameplay_running then
		return false
	end

	if not World_are_particles_playing(world, particle_id) then
		return true
	end

	local cached = _cloud_cache[particle_id]

	if cached then
		local hits = 0

		for i = 1, #cached do
			local cloud = cached[i]

			if World_has_particles_material(world, particle_id, cloud) then
				World_set_particles_material_scalar(world, particle_id, cloud, VARIABLE, value)

				hits = hits + 1
			end
		end

		if hits == #cached then
			return true
		end
	end

	local found = {}

	for i = 1, MAX_CLOUDS do
		local cloud = CLOUDS[i]

		if World_has_particles_material(world, particle_id, cloud) then
			World_set_particles_material_scalar(world, particle_id, cloud, VARIABLE, value)

			found[#found + 1] = cloud
		end
	end

	_cloud_cache[particle_id] = found[1] and found or nil

	return found[1] ~= nil
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

local _pending_tints = {}
local _effect_stats = rawget(_G, "__polychromatic_effect_stats") or {}

rawset(_G, "__polychromatic_effect_stats", _effect_stats)

local function effect_stat(effect_name, set_id, category)
	local stat = _effect_stats[effect_name]

	if not stat then
		stat = { set = set_id, category = category, seen = 0, applied = 0, deferred = 0, late = 0, expired = 0, substituted = 0 }
		_effect_stats[effect_name] = stat
	end

	stat.set = set_id or stat.set
	stat.category = category or stat.category

	return stat
end

local function apply_or_defer(stat, world, particle_id, apply, first, second, third)
	stat.seen = stat.seen + 1

	if apply(world, particle_id, first, second, third) then
		stat.applied = stat.applied + 1

		return
	end

	stat.deferred = stat.deferred + 1

	_pending_tints[#_pending_tints + 1] = {
		stat = stat,
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

		if entry.apply(entry.world, entry.particle_id, entry.first, entry.second, entry.third) then
			entry.stat.late = entry.stat.late + 1
			table.remove(_pending_tints, i)
		elseif entry.frames >= STEPS.pending_tint_frames then
			entry.stat.expired = entry.stat.expired + 1
			table.remove(_pending_tints, i)
		end
	end
end

local function clear_pending_tints()
	for i = #_pending_tints, 1, -1 do
		_pending_tints[i] = nil
	end

	for particle_id in pairs(_cloud_cache) do
		_cloud_cache[particle_id] = nil
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
	if not Managers.package or not asset_redirect then
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

	if spawn_name ~= effect_name then
		local stat = effect_stat(effect_name)

		stat.substituted = stat.substituted + 1
	end

	if not particle_id then
		return particle_id
	end

	if UNREACHABLE_EFFECTS[effect_name] or BURN_PALETTES[effect_name] then
		return particle_id
	end

	local profile = _spawn_context_active and _spawn_context[effect_name]

	if profile then
		apply_or_defer(effect_stat(effect_name, profile.set, profile.category), world, particle_id, apply_spawn, profile, nil, effect_name)

		return particle_id
	end

	local flash = FLASH_EFFECTS[effect_name]

	if flash then
		if not redshift_owns_sniper() then
			profile = profile_for("sniper", "enemy")

			if profile then
				apply_or_defer(effect_stat(effect_name, "sniper", "enemy"), world, particle_id, apply_flash, flash, profile)
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
		apply_or_defer(effect_stat(effect_name, set_id, _spawn_owner or "enemy"), world, particle_id, apply_spawn, profile, variable, effect_name)
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

local SLOT_SCRIPT_SPAWNERS = {
	ForceWeaponBlockEffects = { "update" },
	ForceWeaponWindSlashStageEffects = { "update", "wield" },
	ForceWeaponWindSlashActivationEffects = { "update_unit_position" },
	PlasmagunOverheatEffects = { "update" },
}
local _slot_script_owners = setmetatable({}, { __mode = "k" })

local function slot_script_category(slot_script)
	local category = _slot_script_owners[slot_script]

	if type(category) ~= "string" then
		category = player_category(category or slot_script._owner_unit)
		_slot_script_owners[slot_script] = category
	end

	return category
end

for class_name, methods in pairs(SLOT_SCRIPT_SPAWNERS) do
	mod:hook_safe(CLASS[class_name], "init", function(self, context)
		_slot_script_owners[self] = context and context.owner_unit
	end)

	for i = 1, #methods do
		mod:hook(CLASS[class_name], methods[i], function(func, self, ...)
			return call_with_owner(slot_script_category(self), func, self, ...)
		end)
	end
end

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

local BURN_IDS = {
	soulblaze_buff = "warp_fire",
	ailment_templates = require("scripts/settings/ailments/ailment_settings").effect_templates,
	soulblaze_ailment = require("scripts/settings/ailments/ailment_settings").effects.warpfire,
	flamer_buff = "flamer_assault",
	flamer_ailment = require("scripts/settings/ailments/ailment_settings").effects.burning,
}
local BURN_TIMING_VARIABLE = "offset_time_duration"
local BURN_UNPATCHED_BREED_PATTERNS = { "daemonhost" }
local BURN_HUE_STEPS = 256
local BURN_CODE_SCALE = 4
local _burn_starts = setmetatable({}, { __mode = "k" })

mod:hook_safe(require("scripts/utilities/ailment"), "play_ailment_effect_template", function(unit, ailment_effect, optional_include_children, optional_custom_duration, optional_custom_offset_time)
	if (ailment_effect ~= BURN_IDS.soulblaze_ailment and ailment_effect ~= BURN_IDS.flamer_ailment) or not unit or not Unit.alive(unit) then
		return
	end

	local template = BURN_IDS.ailment_templates[ailment_effect]

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

	return saturation_step * STEPS.burn_saturation + hue_step * 16 + brightness_step
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

local _pending_soul_swaps = {}
local _pending_soul_attach = {}

local function swap_soulblaze_flame(extension, unit, profile, t)
	if not soul_slots_ready() then
		return
	end

	local slot = soul_slot_for(profile, t)

	if slot then
		_pending_soul_swaps[#_pending_soul_swaps + 1] = { extension = extension, unit = unit, slot = slot, wait = STEPS.soul_swap_delay_frames }
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
			_pending_soul_attach[#_pending_soul_attach + 1] = { world = world, unit = unit, particle_id = particle_id, wait = STEPS.soul_attach_frames }
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
	if template_name ~= BURN_IDS.flamer_buff then
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

	if not _soulblaze_enabled or buff_instance:template().name ~= BURN_IDS.soulblaze_buff then
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

	if not _material_format.ok then
		mod:info("game material format %s, payload built for %s: every patched file stays stock", tostring(_material_format.found), tostring(_material_format.expected))
		mod:echo(mod:localize("game_format_changed"))
	end

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
			if _debug_logging then
				mod:info("redirect %s: %s", REDIRECTS[i].stock, state)
			end
		end

		restart = restart or state == "restart_required"
	end

	if _debug_logging then
		mod:info("redirects served: %d of %d", served, #_redirect_handles)
	end

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

	if _debug_logging then
		mod:info("burn shader patch served: %s", tostring(_burn_patch_served))
	end

	local soul_usable = 0

	for i = 1, #SOUL_SLOTS do
		local slot = SOUL_SLOTS[i]

		slot.usable = redirect_served(asset_redirect.state(_redirect_handles[slot.bundle_redirect])) and redirect_served(asset_redirect.state(_redirect_handles[slot.material_redirect]))

		if slot.usable then
			soul_usable = soul_usable + 1
		end
	end

	if _debug_logging then
		mod:info("soulblaze flame slots usable: %d of %d", soul_usable, #SOUL_SLOTS)
	end

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

	if _debug_logging then
		mod:info("las glow slots usable: %d of %d", glow_usable, glow_total)
	end

	if in_level then
		load_soul_slots()
		load_glow_slots()
		pin_extended_packages()
	end

	if restart then
		mod:echo(mod:localize("restart_required"))
	end
end

local diagnostics = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/Polychromatic_debug")({
	mod = mod,
	redirects = REDIRECTS,
	payload_dir = SOUL_PAYLOAD_DIR,
	soul_slots = SOUL_SLOTS,
	glow_slots = GLOW_SLOTS,
	extended_packages = EXTENDED_PACKAGES,
	sets = SETS,
	asset_redirect = asset_redirect,
	redirect_handles = _redirect_handles,
	redirect_served = redirect_served,
	profile_for = profile_for,
	redshift_owns_sniper = redshift_owns_sniper,
	effect_stats = _effect_stats,
	soul_load_ids = _soul_load_ids,
	glow_load_ids = _glow_load_ids,
	extended_load_ids = _extended_load_ids,
	flags = function()
		return {
			gameplay_running = _gameplay_running,
			burn_patch_served = _burn_patch_served,
			soulblaze = _soulblaze_enabled,
			flamer_burn = _flamer_burn_enabled,
			skull_burn = _skull_burn_enabled,
			debug_logging = _debug_logging,
		}
	end,
})

mod:hook_safe(CLASS.PackageManager, "load", function(self, package_name, reference_name, callback, prioritize, use_resident_loading)
	if _debug_logging then
		diagnostics.package_loaded(package_name, reference_name, prioritize, use_resident_loading)
	end
end)

mod:command("poly_check", mod:localize("poly_check_description"), function()
	diagnostics.check_setup(false)
end)

local report_load = mod.on_all_mods_loaded

mod.on_all_mods_loaded = function()
	report_load()

	if _debug_logging then
		diagnostics.check_setup(true, true)
	end
end

local apply_setting = mod.on_setting_changed

mod.on_setting_changed = function(setting_id)
	local was_logging = _debug_logging

	apply_setting(setting_id)

	if setting_id == "debug_logging" and _debug_logging and not was_logging then
		diagnostics.check_setup(true, true)
	end
end
