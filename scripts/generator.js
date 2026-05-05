const fs = require("fs");

// ---------------- CONFIG ----------------
const MAX_CITIES = 40;
const MIN_SALONS_PER_CITY = 5;

// ---------------- CITIES (RYK + surroundings prioritized) ----------------
const cities = [
  "Rahim Yar Khan","Sadiqabad","Khanpur","Liaquatpur",
  "Bahawalpur","Ahmedpur East","Yazman",
  "Multan","Lodhran","Dunyapur",
  "Dera Ghazi Khan","Rajanpur","Kot Mithan",
  "Muzaffargarh","Alipur","Jatoi",
  "Vehari","Burewala","Mailsi",
  "Khanewal","Kabirwala","Mian Channu",
  "Sahiwal","Chichawatni","Arifwala",
  "Okara","Renala Khurd","Depalpur",
  "Faisalabad","Jaranwala","Samundri",
  "Lahore","Kasur","Sheikhupura",
  "Gujranwala","Sialkot","Narowal",
  "Sargodha","Mianwali","Bhakkar"
].slice(0, MAX_CITIES);

// ---------------- LARGE NAME POOLS ----------------
const maleNames = [
  "Ali","Usman","Bilal","Hassan","Imran","Zain","Farhan","Adnan","Tariq","Nadeem",
  "Rizwan","Kamran","Sajid","Waqas","Asif","Shahid","Yasir","Junaid","Saad","Hamza",
  "Faisal","Owais","Shahbaz","Mudassar","Tanveer","Adeel","Rashid","Noman","Aamir","Kashif",
  "Sohail","Zubair","Zeeshan","Irfan","Arslan","Haris","Danish","Salman","Qasim","Naveed",
  "Azhar","Majid","Shafqat","Rauf","Latif","Akram","Younas","Basit","Shakir","Fahad"
];

const femaleNames = [
  "Ayesha","Hina","Sadia","Mehwish","Komal","Rabia","Sana","Nadia","Hira","Areeba",
  "Iqra","Maria","Zara","Fatima","Noor","Laiba","Mahnoor","Saba","Kiran","Bushra",
  "Nimra","Alina","Minal","Eman","Amna","Sidra","Anum","Fiza","Uzma","Shazia",
  "Noreen","Saima","Farah","Lubna","Rukhsar","Parveen","Samina","Tehmina","Khadija","Sumaira",
  "Nargis","Yasmeen","Zainab","Hafsa","Sehrish","Afshan","Naima","Shaista","Asma","Rubina"
];

const lastNames = [
  "Khan","Malik","Sheikh","Raza","Ahmed","Iqbal","Qureshi","Javed","Butt","Chaudhry",
  "Abbasi","Ansari","Siddiqui","Farooq","Mirza","Hashmi","Nawaz","Bhatti","Dar","Gondal",
  "Gill","Warraich","Bukhari","Shah","Akhtar","Rashid","Latif","Hussain","Zafar","Mughal",
  "Khokhar","Awan","Randhawa","Baloch","Chishti","Naqvi","Tariq","Sabir","Aslam","Feroz",
  "Jamil","Rauf","Basheer","Hanif","Munir","Yaqoob","Sharif","Khalid","Sohail","Masood"
];

// ---------------- SERVICES (60+) ----------------
const servicesPool = [
  "Haircut","Hair Coloring","Hair Highlights","Keratin Treatment","Facial","Manicure","Pedicure","Waxing","Bridal Makeup","Hair Spa",
  "Beard Trim","Hair Straightening","Protein Treatment","Scalp Treatment","Threading","Bleach","Cleanup","Party Makeup","Engagement Makeup","HD Makeup",
  "Airbrush Makeup","Hair Rebonding","Hair Smoothening","Dandruff Treatment","Head Massage","Foot Massage","Hand Massage","Nail Art","Gel Nails","Acrylic Nails",
  "Eyebrow Tint","Eyelash Extensions","Hair Botox","Skin Polishing","Body Scrub","Body Polish","Body Wax","Full Body Massage","Hot Oil Treatment","Hair Glossing",
  "Color Correction","Hair Extensions","Fringe Cut","Kids Haircut","Men Grooming","Shaving","Mustache Styling","Deep Cleansing Facial","Gold Facial","Diamond Facial",
  "Anti-Aging Facial","Acne Treatment","Skin Brightening","Under Eye Treatment","Detan Facial","Hydrafacial","Microblading","Hair Fall Treatment","Olaplex Treatment","Hair Volumizing"
];

// ---------------- SPECIALTIES ----------------
const specialties = [
  "Hair Styling","Hair Cutting","Beard Styling","Makeup Artist","Skin Care","Hair Coloring","Facials","Party Makeup",
  "Bridal Makeup","Keratin Treatments","Hair Spa Specialist","Nail Technician","Massage Therapist","Skin Specialist",
  "Hair Extensions","Makeup Consultant","Grooming Expert","Cosmetologist","Beauty Therapist","Hair Repair Specialist"
];

// ---------------- HELPERS ----------------
const usedNames = new Set();
let idCounter = 1000;

function random(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function shuffle(arr) {
  return arr.sort(() => 0.5 - Math.random());
}

function uniqueSalonName(city) {
  let name;
  do {
    name = `${random(["Royal","Elite","Urban","Glam","Prime","Classic","Signature","Platinum"])} ${random(["Salon","Studio","Lounge","Makeover","Beauty Hub"])} ${city}`;
  } while (usedNames.has(name));
  usedNames.add(name);
  return name;
}

function generateStylists() {
  const stylists = [];

  for (let i = 0; i < 5; i++) {
    stylists.push({
      name: `${random(maleNames)} ${random(lastNames)}`,
      gender: "male",
      specialty: random(specialties)
    });
  }

  for (let i = 0; i < 5; i++) {
    stylists.push({
      name: `${random(femaleNames)} ${random(lastNames)}`,
      gender: "female",
      specialty: random(specialties)
    });
  }

  return stylists;
}

function pickTopStylists(stylists) {
  const male = stylists.find(s => s.gender === "male");
  const female = stylists.find(s => s.gender === "female");

  return [
    { name: male.name, specialty: male.specialty },
    { name: female.name, specialty: female.specialty }
  ];
}

function generateServices() {
  const shuffled = shuffle([...servicesPool]);
  const count = Math.floor(Math.random() * 5) + 8; // 8–12 services
  return shuffled.slice(0, count).map(s => ({
    service_name: s,
    price: Math.floor(Math.random() * 15000 + 1500),
    duration_time: `${Math.floor(Math.random() * 120 + 20)} min`
  }));
}

// ---------------- MAIN ----------------
function generateData() {
  const data = [];

  cities.forEach(city => {
    for (let i = 0; i < MIN_SALONS_PER_CITY; i++) {

      const stylists = generateStylists();

      data.push({
        id: `PK-PB-${idCounter++}`,
        name: uniqueSalonName(city),
        state: "Punjab",
        city: city,
        rating: parseFloat((Math.random() * (4.8 - 4.0) + 4.0).toFixed(1)),
        reviews_count: Math.floor(Math.random() * 2000 + 300),
        distance_km: parseFloat((Math.random() * 10).toFixed(1)),
        full_address: `${random(["Main Road","Model Town","City Center","Cantt Area","Mall Road"])}, ${city}`,
        opening_hours: { "days": "Monday - Sunday", "timing": "10:30 AM - 08:30 PM" },
        short_description: "Modern beauty studio with personalized services.",
        services: generateServices(),
        stylists: stylists.map(s => ({ name: s.name, specialty: s.specialty })),
        top_rated_stylists: pickTopStylists(stylists),
        discount_offer: `${Math.floor(Math.random() * 15 + 5)}% off between 3:00 PM - 5:00 PM`
      });
    }
  });

  return data;
}

// ---------------- RUN ----------------
const dataset = generateData();
fs.writeFileSync("salons.json", JSON.stringify(dataset, null, 2));

console.log(`Generated ${dataset.length} salons across ${cities.length} cities`);