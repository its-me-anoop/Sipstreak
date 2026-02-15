var dom = require('sketch/dom');
var Document = dom.Document;
var Page = dom.Page;
var Artboard = dom.Artboard;
var SymbolMaster = dom.SymbolMaster;
var Rectangle = dom.Rectangle;
var ShapePath = dom.ShapePath;
var Text = dom.Text;
var Group = dom.Group;
var HotSpot = dom.HotSpot;

var OUTPUT_PATH = '/Users/anoopjose/Documents/New project/design/ArtKeep/ArtKeep_iOS_v1.sketch';

var COLORS = {
  ink: '#1F2328',
  paper: '#F7F2E8',
  coral: '#E87055',
  sage: '#7FAE8D',
  sky: '#8BB9D9',
  sand: '#E9DEC9',
  white: '#FFFFFF',
  line: '#1F232833',
  muted: '#5A6570',
  overlay: '#1F232855'
};

function safeCorners(shape, radius) {
  try {
    var pts = shape.points;
    for (var i = 0; i < pts.length; i += 1) {
      pts[i].cornerRadius = radius;
    }
  } catch (e) {
    // Keep going if the layer type does not expose editable corners.
  }
}

function makeRect(parent, x, y, w, h, fill, border, radius, shadow) {
  var style = {
    fills: [fill || COLORS.white]
  };
  if (border) {
    style.borders = [{ color: border, thickness: 1 }];
  }
  if (shadow) {
    style.shadows = [{
      color: '#0000001A',
      x: 0,
      y: 8,
      blur: 18,
      spread: 0
    }];
  }

  var rect = new ShapePath({
    parent: parent,
    shapeType: ShapePath.ShapeType.Rectangle,
    frame: new Rectangle(x, y, w, h),
    style: style
  });
  if (radius) {
    safeCorners(rect, radius);
  }
  return rect;
}

function makeText(parent, content, x, y, w, h, token, align) {
  var style = {
    textColor: COLORS.ink,
    alignment: align || 'left'
  };

  if (token === 'display') {
    style.fontFamily = 'New York';
    style.fontSize = 34;
    style.fontWeight = 7;
    style.lineHeight = 40;
  } else if (token === 'title') {
    style.fontFamily = 'New York';
    style.fontSize = 27;
    style.fontWeight = 6;
    style.lineHeight = 33;
  } else if (token === 'headline') {
    style.fontFamily = 'SF Pro Text';
    style.fontSize = 20;
    style.fontWeight = 6;
    style.lineHeight = 26;
  } else if (token === 'button') {
    style.fontFamily = 'SF Pro Text';
    style.fontSize = 17;
    style.fontWeight = 7;
    style.lineHeight = 22;
  } else if (token === 'caption') {
    style.fontFamily = 'SF Pro Text';
    style.fontSize = 12;
    style.fontWeight = 4;
    style.lineHeight = 16;
    style.textColor = COLORS.muted;
  } else if (token === 'mono') {
    style.fontFamily = 'SF Mono';
    style.fontSize = 12;
    style.fontWeight = 5;
    style.lineHeight = 16;
  } else {
    style.fontFamily = 'SF Pro Text';
    style.fontSize = 15;
    style.fontWeight = 4;
    style.lineHeight = 21;
  }

  return new Text({
    parent: parent,
    text: content,
    frame: new Rectangle(x, y, w, h),
    style: style
  });
}

function addTopChrome(ab, subtitle) {
  makeText(ab, '9:41', 24, 16, 70, 20, 'caption', 'left');
  makeText(ab, 'ArtKeep', 146, 16, 100, 20, 'caption', 'center');
  makeText(ab, '5G 88%', 300, 16, 70, 20, 'caption', 'right');

  makeRect(ab, 0, 44, ab.frame.width, 112, COLORS.paper, null, 0, false);
  makeRect(ab, 244, 56, 120, 80, '#F0E4D2', null, 36, false);
  makeRect(ab, 24, 66, 44, 44, COLORS.sky, null, 22, false);
  makeText(ab, 'AK', 24, 77, 44, 24, 'button', 'center');
  makeText(ab, subtitle || 'Private family archive', 80, 72, 260, 44, 'caption', 'left');

  makeRect(ab, 305, 58, 64, 32, COLORS.coral, null, 16, false);
  makeText(ab, 'Next', 305, 64, 64, 20, 'caption', 'center').style.textColor = COLORS.white;
}

function addPrimaryButton(ab, label, y, fill) {
  makeRect(ab, 24, y, 345, 54, fill || COLORS.coral, null, 18, true);
  var t = makeText(ab, label, 24, y + 16, 345, 24, 'button', 'center');
  t.style.textColor = COLORS.white;
}

function addTabBar(ab, activeTab) {
  makeRect(ab, 0, 774, 393, 78, '#F9F5ED', '#1F232811', 0, false);
  var tabs = ['Home', 'Capture', 'Timeline', 'Fridge', 'Shop'];
  var x = 8;
  for (var i = 0; i < tabs.length; i += 1) {
    var isActive = tabs[i] === activeTab;
    if (isActive) {
      makeRect(ab, x - 4, 787, 72, 34, '#F8E0D9', null, 17, false);
    }
    var label = makeText(ab, tabs[i], x, 796, 64, 20, 'caption', 'center');
    if (isActive) {
      label.style.textColor = COLORS.coral;
    }
    x += 76;
  }
}

function addListCard(parent, x, y, w, h, title, subtitle, badge) {
  makeRect(parent, x, y, w, h, COLORS.white, '#1F232822', 16, true);
  makeRect(parent, x + 12, y + 12, 58, h - 24, '#F2E8D8', null, 12, false);
  makeText(parent, title, x + 82, y + 14, w - 140, 24, 'headline', 'left');
  makeText(parent, subtitle, x + 82, y + 42, w - 120, 30, 'body', 'left');
  if (badge) {
    makeRect(parent, x + w - 86, y + 16, 70, 24, '#E6F2EA', null, 12, false);
    makeText(parent, badge, x + w - 86, y + 21, 70, 16, 'caption', 'center').style.textColor = COLORS.sage;
  }
}

function addScannerViewport(parent, y, label) {
  makeRect(parent, 16, y, 361, 432, '#2B2B2E', null, 24, true);
  makeRect(parent, 44, y + 36, 305, 360, '#161719', '#FFFFFF33', 16, false);
  makeRect(parent, 44, y + 36, 24, 24, '#FFFFFF00', '#FFFFFF99', 4, false);
  makeRect(parent, 325, y + 36, 24, 24, '#FFFFFF00', '#FFFFFF99', 4, false);
  makeRect(parent, 44, y + 372, 24, 24, '#FFFFFF00', '#FFFFFF99', 4, false);
  makeRect(parent, 325, y + 372, 24, 24, '#FFFFFF00', '#FFFFFF99', 4, false);
  makeText(parent, label, 16, y + 404, 361, 22, 'caption', 'center').style.textColor = '#FFFFFF';
}

function setArtboardBackground(ab) {
  try {
    ab.background.enabled = true;
    ab.background.color = COLORS.paper;
    ab.background.includedInExport = true;
  } catch (e) {
    // Some contexts may not expose full background API.
  }
}

function buildIPhoneScreen(ab, screen) {
  setArtboardBackground(ab);
  makeRect(ab, 0, 0, 393, 852, COLORS.paper, null, 0, false);
  addTopChrome(ab, screen.subtitle);

  makeText(ab, screen.title, 24, 118, 320, 32, 'title', 'left');
  makeText(ab, screen.subtitle, 24, 150, 345, 24, 'caption', 'left');

  var kind = screen.kind;

  if (kind === 'splash') {
    makeRect(ab, 66, 232, 260, 260, '#F0E4D2', null, 48, true);
    makeRect(ab, 132, 298, 128, 128, COLORS.coral, null, 32, false);
    makeText(ab, 'AK', 132, 342, 128, 40, 'display', 'center').style.textColor = COLORS.white;
    makeText(ab, 'Turn clutter into forever memories.', 44, 510, 305, 46, 'headline', 'center');
    addPrimaryButton(ab, 'Begin', 744, COLORS.coral);
  } else if (kind === 'onboarding') {
    makeRect(ab, 24, 194, 345, 258, '#F2E8D8', '#1F232822', 24, true);
    makeText(ab, 'What you get', 44, 222, 180, 26, 'headline', 'left');
    addListCard(ab, 44, 258, 305, 56, 'Auto clean scan', 'Crop, deskew, remove shadows', null);
    addListCard(ab, 44, 322, 305, 56, 'Timeline tags', 'Noah • 4y 2m', 'AI');
    addListCard(ab, 44, 386, 305, 56, 'Family fridge', 'Invite-only comments & stickers', null);
    addPrimaryButton(ab, 'Continue', 744, COLORS.coral);
  } else if (kind === 'setup') {
    makeRect(ab, 24, 208, 345, 70, COLORS.white, '#1F232822', 14, true);
    makeText(ab, 'Child Name', 40, 220, 120, 20, 'caption', 'left');
    makeText(ab, 'Noah', 40, 242, 220, 24, 'headline', 'left');
    makeRect(ab, 24, 292, 345, 70, COLORS.white, '#1F232822', 14, true);
    makeText(ab, 'Birth Date', 40, 304, 120, 20, 'caption', 'left');
    makeText(ab, 'June 10, 2021', 40, 326, 220, 24, 'headline', 'left');

    makeRect(ab, 24, 382, 345, 164, '#F2E8D8', '#1F232811', 16, false);
    makeText(ab, 'Avatar & tag color', 40, 400, 180, 22, 'headline', 'left');
    var x = 44;
    var cols = [COLORS.coral, COLORS.sage, COLORS.sky, '#D69DB3'];
    for (var i = 0; i < cols.length; i += 1) {
      makeRect(ab, x, 440, 64, 64, cols[i], null, 32, false);
      x += 74;
    }
    addPrimaryButton(ab, 'Save Child Profile', 744, COLORS.coral);
  } else if (kind === 'permissions') {
    addListCard(ab, 24, 210, 345, 78, 'Camera', 'Capture drawings with auto-crop', 'Allow');
    addListCard(ab, 24, 300, 345, 78, 'Microphone', 'Record voice memos', 'Allow');
    addListCard(ab, 24, 390, 345, 78, 'Photos', 'Save edited scans', 'Allow');
    addListCard(ab, 24, 480, 345, 78, 'Notifications', 'New masterpiece alerts', 'Allow');
    addPrimaryButton(ab, 'Enable All', 744, COLORS.coral);
  } else if (kind === 'paywall') {
    makeRect(ab, 24, 200, 345, 170, COLORS.white, '#1F232822', 20, true);
    makeText(ab, 'Free', 44, 220, 140, 22, 'headline', 'left');
    makeText(ab, 'Up to 50 artworks\nWatermarked downloads', 44, 248, 220, 48, 'body', 'left');
    makeRect(ab, 24, 382, 345, 214, '#FDEEE9', '#E870554D', 20, true);
    makeText(ab, 'Curator Mode', 44, 406, 220, 26, 'headline', 'left').style.textColor = COLORS.coral;
    makeText(ab, '$4.99 / month\nUnlimited storage\nNo watermark\nMulti-child profiles', 44, 438, 240, 94, 'body', 'left');
    makeRect(ab, 252, 406, 94, 28, COLORS.coral, null, 14, false);
    makeText(ab, 'Popular', 252, 412, 94, 16, 'caption', 'center').style.textColor = COLORS.white;
    addPrimaryButton(ab, 'Start 7-Day Trial', 744, COLORS.coral);
  } else if (kind === 'cta') {
    makeRect(ab, 24, 214, 345, 270, '#F2E8D8', '#1F232822', 24, true);
    makeRect(ab, 136, 266, 122, 122, COLORS.sage, null, 61, false);
    makeText(ab, '✓', 136, 298, 122, 60, 'display', 'center').style.textColor = COLORS.white;
    makeText(ab, 'Ready for your first masterpiece', 48, 410, 300, 40, 'headline', 'center');
    addPrimaryButton(ab, 'Scan First Masterpiece', 744, COLORS.coral);
  } else if (kind === 'dashboard') {
    addListCard(ab, 24, 198, 345, 94, 'Recent: Dinosaur Pizza', 'Noah • Age 4y 2m • Today', 'New');
    makeRect(ab, 24, 304, 345, 112, COLORS.white, '#1F232822', 16, true);
    makeText(ab, 'Storage Meter', 40, 324, 170, 24, 'headline', 'left');
    makeRect(ab, 40, 356, 250, 16, '#EFE8DA', null, 8, false);
    makeRect(ab, 40, 356, 162, 16, COLORS.sage, null, 8, false);
    makeText(ab, '32 / 50 pieces', 296, 354, 64, 18, 'caption', 'right');
    makeRect(ab, 24, 430, 345, 150, '#FDEEE9', '#E8705533', 16, true);
    makeText(ab, 'Holiday Upsell', 40, 450, 180, 24, 'headline', 'left');
    makeText(ab, 'Turn favorites into mugs, cards, or a Year in Art book.', 40, 480, 230, 48, 'body', 'left');
    makeRect(ab, 280, 514, 74, 34, COLORS.coral, null, 17, false);
    makeText(ab, 'Shop', 280, 522, 74, 18, 'caption', 'center').style.textColor = COLORS.white;
    addTabBar(ab, screen.tab);
  } else if (kind === 'capture') {
    addScannerViewport(ab, 186, 'AI edge detect • Shadow removal • Auto color');
    makeRect(ab, 160, 640, 74, 74, COLORS.white, '#1F232822', 37, true);
    makeRect(ab, 176, 656, 42, 42, COLORS.coral, null, 21, false);
    addTabBar(ab, screen.tab);
  } else if (kind === 'editor') {
    addScannerViewport(ab, 186, 'Adjust corners and perspective');
    makeRect(ab, 24, 640, 345, 72, COLORS.white, '#1F232822', 16, true);
    makeRect(ab, 36, 658, 98, 36, '#F8E0D9', null, 18, false);
    makeText(ab, 'Auto', 36, 667, 98, 18, 'caption', 'center').style.textColor = COLORS.coral;
    makeRect(ab, 146, 658, 98, 36, '#EEF4F0', null, 18, false);
    makeText(ab, 'Manual', 146, 667, 98, 18, 'caption', 'center').style.textColor = COLORS.sage;
    makeRect(ab, 256, 658, 98, 36, '#EDF3F8', null, 18, false);
    makeText(ab, 'Enhance', 256, 667, 98, 18, 'caption', 'center').style.textColor = COLORS.sky;
    addTabBar(ab, screen.tab);
  } else if (kind === 'metadata') {
    addListCard(ab, 24, 198, 345, 74, 'Title', 'Dinosaur Eating Pizza', null);
    addListCard(ab, 24, 284, 345, 74, 'Child', 'Noah', null);
    addListCard(ab, 24, 370, 345, 74, 'Date', 'Today', null);
    addListCard(ab, 24, 456, 345, 74, 'Medium', 'Crayon on paper', null);
    addPrimaryButton(ab, 'Attach Voice Memo', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  } else if (kind === 'voice') {
    makeRect(ab, 24, 198, 345, 230, COLORS.white, '#1F232822', 20, true);
    makeText(ab, 'Voice Memo', 40, 224, 200, 24, 'headline', 'left');
    makeText(ab, '"This is a dinosaur eating pizza!"', 40, 260, 290, 42, 'body', 'left');
    makeRect(ab, 140, 318, 112, 112, '#FDEEE9', '#E8705533', 56, false);
    makeRect(ab, 172, 350, 48, 48, COLORS.coral, null, 24, false);
    makeRect(ab, 24, 446, 345, 100, '#F2E8D8', '#1F232811', 16, false);
    makeText(ab, 'Mic permission fallback', 40, 468, 220, 22, 'headline', 'left');
    makeText(ab, 'If denied, show Settings deep-link CTA.', 40, 494, 290, 30, 'body', 'left');
    addPrimaryButton(ab, 'Save Artwork', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  } else if (kind === 'success') {
    makeRect(ab, 24, 216, 345, 250, '#EEF4F0', '#7FAE8D55', 24, true);
    makeRect(ab, 148, 260, 96, 96, COLORS.sage, null, 48, false);
    makeText(ab, '✓', 148, 288, 96, 42, 'display', 'center').style.textColor = COLORS.white;
    makeText(ab, 'Saved to Timeline', 72, 370, 250, 30, 'headline', 'center');
    makeText(ab, 'Now share it to your private Virtual Fridge.', 60, 404, 270, 36, 'body', 'center');
    addPrimaryButton(ab, 'Post to Virtual Fridge', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  } else if (kind === 'timeline') {
    makeRect(ab, 24, 194, 102, 30, '#E6F2EA', null, 15, false);
    makeText(ab, 'Noah • 4y 2m', 24, 201, 102, 16, 'caption', 'center').style.textColor = COLORS.sage;
    makeRect(ab, 134, 194, 78, 30, '#EDF3F8', null, 15, false);
    makeText(ab, '2026', 134, 201, 78, 16, 'caption', 'center').style.textColor = COLORS.sky;
    addListCard(ab, 24, 236, 345, 104, 'February 2026', '3 masterpieces added', 'Age');
    addListCard(ab, 24, 352, 345, 104, 'January 2026', '5 masterpieces added', null);
    addListCard(ab, 24, 468, 345, 104, 'December 2025', 'Holiday collection', null);
    addTabBar(ab, screen.tab);
  } else if (kind === 'detail') {
    makeRect(ab, 24, 188, 345, 280, '#F2E8D8', '#1F232822', 20, true);
    makeText(ab, 'Artwork Preview', 40, 208, 200, 24, 'headline', 'left');
    makeRect(ab, 44, 240, 305, 212, COLORS.white, '#1F232822', 14, false);
    makeRect(ab, 24, 482, 345, 144, COLORS.white, '#1F232822', 16, true);
    makeText(ab, 'Noah • 4y 2m', 40, 504, 200, 22, 'headline', 'left');
    makeText(ab, 'Crayon on paper\nCaptured Feb 9, 2026', 40, 530, 220, 40, 'body', 'left');
    makeRect(ab, 276, 534, 78, 34, '#F8E0D9', null, 17, false);
    makeText(ab, 'Favorite', 276, 542, 78, 18, 'caption', 'center').style.textColor = COLORS.coral;
    addTabBar(ab, screen.tab);
  } else if (kind === 'comments') {
    addListCard(ab, 24, 194, 345, 100, 'Grandma', 'This is incredible! ❤️', null);
    addListCard(ab, 24, 306, 345, 100, 'Aunt Mia', 'Frame this for the kitchen!', 'Sticker');
    addListCard(ab, 24, 418, 345, 100, 'Dad', 'Dinosaur has great taste 🍕', null);
    makeRect(ab, 24, 534, 345, 68, COLORS.white, '#1F232822', 14, false);
    makeText(ab, 'Write a comment…', 40, 557, 200, 20, 'caption', 'left');
    addTabBar(ab, screen.tab);
  } else if (kind === 'sticker') {
    makeRect(ab, 24, 194, 345, 340, COLORS.white, '#1F232822', 20, true);
    makeText(ab, 'Pick a Sticker', 40, 216, 220, 24, 'headline', 'left');
    var sx = 48;
    var sy = 258;
    var labels = ['⭐', '🎉', '❤️', '🦕', '🍕', '🏆'];
    for (var j = 0; j < labels.length; j += 1) {
      makeRect(ab, sx, sy, 92, 92, '#F2E8D8', null, 16, false);
      makeText(ab, labels[j], sx, sy + 22, 92, 46, 'display', 'center');
      sx += 104;
      if ((j + 1) % 3 === 0) {
        sx = 48;
        sy += 104;
      }
    }
    addPrimaryButton(ab, 'Send Sticker', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  } else if (kind === 'filter') {
    makeRect(ab, 24, 194, 345, 380, COLORS.white, '#1F232822', 20, true);
    makeText(ab, 'Search, Filter, Sort', 40, 216, 250, 24, 'headline', 'left');
    addListCard(ab, 40, 250, 313, 64, 'Search', 'Title, age tag, date', null);
    addListCard(ab, 40, 326, 313, 64, 'Filter', 'Child, medium, favorites', null);
    addListCard(ab, 40, 402, 313, 64, 'Sort', 'Newest, oldest, most shared', null);
    addPrimaryButton(ab, 'Apply Filters', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  } else if (kind === 'fridge') {
    addListCard(ab, 24, 194, 345, 124, 'Dinosaur Pizza', 'Shared to Family Fridge • 3 comments • 5 stickers', 'Private');
    addListCard(ab, 24, 330, 345, 124, 'Rainbow Castle', 'Shared yesterday • 2 comments', null);
    addListCard(ab, 24, 466, 345, 124, 'Robot Rocket', 'Shared last week • 6 stickers', null);
    addTabBar(ab, screen.tab);
  } else if (kind === 'invite') {
    makeRect(ab, 24, 198, 345, 78, COLORS.white, '#1F232822', 14, true);
    makeText(ab, 'Invite by email or phone', 40, 226, 220, 20, 'caption', 'left');
    makeRect(ab, 24, 290, 345, 144, COLORS.white, '#1F232822', 16, true);
    makeText(ab, 'Roles', 40, 312, 220, 22, 'headline', 'left');
    makeRect(ab, 40, 346, 110, 34, '#F8E0D9', null, 17, false);
    makeText(ab, 'Viewer', 40, 354, 110, 18, 'caption', 'center').style.textColor = COLORS.coral;
    makeRect(ab, 162, 346, 110, 34, '#EEF4F0', null, 17, false);
    makeText(ab, 'Commenter', 162, 354, 110, 18, 'caption', 'center').style.textColor = COLORS.sage;
    addListCard(ab, 24, 448, 345, 84, 'Pending Invite', 'grandma@example.com', 'Sent');
    addPrimaryButton(ab, 'Send Invite', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  } else if (kind === 'notifications') {
    addListCard(ab, 24, 194, 345, 94, 'New Comment', 'Grandma commented on Dinosaur Pizza', 'Now');
    addListCard(ab, 24, 300, 345, 94, 'Holiday Prompt', 'Create Mother\'s Day cards from favorites', 'Today');
    addListCard(ab, 24, 406, 345, 94, 'Storage Alert', 'You\'re at 45/50 free artworks', 'Today');
    addListCard(ab, 24, 512, 345, 94, 'Order Update', 'Year in Art book is in production', 'Yesterday');
    addTabBar(ab, screen.tab);
  } else if (kind === 'shop') {
    makeRect(ab, 24, 194, 345, 94, '#FDEEE9', '#E8705533', 16, true);
    makeText(ab, 'Seasonal Campaign', 40, 214, 190, 22, 'headline', 'left');
    makeText(ab, 'Mother\'s Day gifts from your child\'s art', 40, 240, 220, 26, 'body', 'left');

    var px = 24;
    var py = 302;
    var products = ['Mug', 'Card', 'T-shirt', 'Yearbook'];
    for (var p = 0; p < products.length; p += 1) {
      makeRect(ab, px, py, 166, 138, COLORS.white, '#1F232822', 16, true);
      makeRect(ab, px + 12, py + 12, 142, 76, '#F2E8D8', null, 12, false);
      makeText(ab, products[p], px + 12, py + 94, 142, 22, 'headline', 'center');
      makeText(ab, '$24+', px + 12, py + 116, 142, 18, 'caption', 'center').style.textColor = COLORS.coral;
      px += 179;
      if ((p + 1) % 2 === 0) {
        px = 24;
        py += 150;
      }
    }
    addTabBar(ab, screen.tab);
  } else if (kind === 'cart') {
    addListCard(ab, 24, 194, 345, 92, 'Mug x1', 'Dinosaur Pizza print', '$24');
    addListCard(ab, 24, 298, 345, 92, 'Greeting Cards x10', 'Rainbow Castle print', '$18');
    makeRect(ab, 24, 406, 345, 128, COLORS.white, '#1F232822', 16, true);
    makeText(ab, 'Subtotal', 40, 430, 120, 22, 'headline', 'left');
    makeText(ab, '$42.00', 280, 430, 74, 22, 'headline', 'right');
    makeText(ab, 'Shipping + tax estimated at checkout', 40, 460, 220, 30, 'caption', 'left');
    addPrimaryButton(ab, 'Continue to Checkout', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  } else if (kind === 'checkout') {
    addListCard(ab, 24, 194, 345, 84, 'Shipping', 'Anoop Jose, Austin TX', 'Edit');
    addListCard(ab, 24, 290, 345, 84, 'Payment', 'Visa •••• 4242', 'Edit');
    addListCard(ab, 24, 386, 345, 84, 'Delivery', 'Standard 5-7 business days', null);
    makeRect(ab, 24, 484, 345, 120, COLORS.white, '#1F232822', 16, true);
    makeText(ab, 'Order Total', 40, 512, 140, 22, 'headline', 'left');
    makeText(ab, '$49.60', 280, 512, 74, 22, 'headline', 'right');
    addPrimaryButton(ab, 'Place Order', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  } else if (kind === 'confirmation') {
    makeRect(ab, 24, 204, 345, 318, '#EEF4F0', '#7FAE8D55', 24, true);
    makeRect(ab, 140, 250, 112, 112, COLORS.sage, null, 56, false);
    makeText(ab, '✓', 140, 284, 112, 48, 'display', 'center').style.textColor = COLORS.white;
    makeText(ab, 'Order Confirmed', 76, 378, 240, 30, 'headline', 'center');
    makeText(ab, 'Order #AK-2048\nTracking updates will appear in Notifications.', 72, 414, 248, 44, 'body', 'center');
    addPrimaryButton(ab, 'Back to Home', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  } else if (kind === 'modal') {
    makeRect(ab, 24, 198, 345, 254, COLORS.white, '#1F232822', 20, true);
    makeText(ab, 'Campaign Trigger', 40, 224, 220, 24, 'headline', 'left');
    makeText(ab, 'Mother\'s Day is near.\nTurn top artworks into premium gifts.', 40, 260, 260, 44, 'body', 'left');
    makeRect(ab, 40, 324, 150, 42, '#F8E0D9', null, 21, false);
    makeText(ab, 'Maybe Later', 40, 336, 150, 18, 'caption', 'center').style.textColor = COLORS.coral;
    makeRect(ab, 204, 324, 150, 42, COLORS.coral, null, 21, false);
    makeText(ab, 'Start Now', 204, 336, 150, 18, 'caption', 'center').style.textColor = COLORS.white;
    makeRect(ab, 0, 0, 393, 852, COLORS.overlay, null, 0, false).style.opacity = 0.22;
    addTabBar(ab, screen.tab);
  } else if (kind === 'storage') {
    makeRect(ab, 24, 198, 345, 250, COLORS.white, '#1F232822', 20, true);
    makeText(ab, 'Free Tier Usage', 40, 224, 220, 24, 'headline', 'left');
    makeRect(ab, 126, 260, 140, 140, '#F2E8D8', null, 70, false);
    makeRect(ab, 140, 274, 112, 112, '#FFFFFF', null, 56, false);
    makeText(ab, '32/50', 140, 318, 112, 26, 'headline', 'center');
    makeText(ab, 'Pieces', 140, 346, 112, 20, 'caption', 'center');
    makeText(ab, 'Watermarked download applies on free plan.', 40, 412, 280, 24, 'body', 'left');
    addTabBar(ab, screen.tab);
  } else if (kind === 'upsell') {
    makeRect(ab, 24, 198, 345, 310, '#FDEEE9', '#E870554D', 20, true);
    makeText(ab, 'Limit Reached', 40, 226, 220, 26, 'headline', 'left').style.textColor = COLORS.coral;
    makeText(ab, 'You\'ve reached 50 artworks.\nUpgrade to Curator Mode for unlimited storage and high-res downloads.', 40, 260, 280, 72, 'body', 'left');
    addListCard(ab, 40, 346, 313, 64, 'Unlimited Cloud Storage', 'Keep every masterpiece forever', null);
    addListCard(ab, 40, 420, 313, 64, 'No Watermark', 'Share high-resolution originals', null);
    addPrimaryButton(ab, 'Upgrade for $4.99/mo', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  } else if (kind === 'subscription') {
    addListCard(ab, 24, 198, 345, 84, 'Current Plan', 'Curator Mode (Monthly)', 'Active');
    addListCard(ab, 24, 294, 345, 84, 'Renewal Date', 'March 9, 2026', null);
    addListCard(ab, 24, 390, 345, 84, 'Manage Billing', 'Open App Store Subscription', 'Open');
    makeRect(ab, 24, 490, 345, 112, '#EEF4F0', '#7FAE8D44', 16, false);
    makeText(ab, 'Included Features', 40, 514, 180, 22, 'headline', 'left');
    makeText(ab, 'Unlimited storage • Multi-child profiles • No watermark', 40, 540, 300, 36, 'body', 'left');
    addTabBar(ab, screen.tab);
  } else if (kind === 'profiles') {
    addListCard(ab, 24, 198, 345, 94, 'Noah', '4y 2m • 52 artworks', 'Primary');
    addListCard(ab, 24, 304, 345, 94, 'Emma', '2y 11m • 14 artworks', 'Added');
    makeRect(ab, 24, 420, 345, 126, '#F2E8D8', '#1F232822', 16, false);
    makeText(ab, 'Add another child profile', 40, 446, 220, 24, 'headline', 'left');
    makeText(ab, 'Available on Curator Mode', 40, 474, 200, 22, 'caption', 'left');
    makeRect(ab, 254, 454, 100, 36, COLORS.coral, null, 18, false);
    makeText(ab, 'Add Child', 254, 463, 100, 18, 'caption', 'center').style.textColor = COLORS.white;
    addTabBar(ab, screen.tab);
  } else if (kind === 'settings') {
    addListCard(ab, 24, 198, 345, 74, 'Privacy', 'Invite-only sharing enabled', 'On');
    addListCard(ab, 24, 284, 345, 74, 'Notifications', 'Fridge comments and campaign prompts', 'On');
    addListCard(ab, 24, 370, 345, 74, 'Data Export', 'Download family archive', null);
    addListCard(ab, 24, 456, 345, 74, 'Delete Account', 'Permanent removal and cloud purge', null);
    addListCard(ab, 24, 542, 345, 74, 'Terms & Privacy', 'View legal documents', null);
    addTabBar(ab, screen.tab);
  } else if (kind === 'states') {
    makeRect(ab, 24, 198, 345, 126, '#F2E8D8', '#1F232822', 16, true);
    makeText(ab, 'Empty State', 40, 224, 200, 24, 'headline', 'left');
    makeText(ab, 'No artworks yet. Scan your first masterpiece.', 40, 252, 250, 24, 'body', 'left');
    makeRect(ab, 24, 338, 345, 126, '#FDEEE9', '#E8705533', 16, true);
    makeText(ab, 'Error State', 40, 364, 200, 24, 'headline', 'left');
    makeText(ab, 'Upload failed. Retry or save locally.', 40, 392, 250, 24, 'body', 'left');
    makeRect(ab, 24, 478, 345, 126, '#EDF3F8', '#8BB9D944', 16, true);
    makeText(ab, 'Loading State', 40, 504, 200, 24, 'headline', 'left');
    makeText(ab, 'Enhancing image quality...', 40, 532, 250, 24, 'body', 'left');
    addTabBar(ab, screen.tab);
  } else if (kind === 'offline') {
    makeRect(ab, 24, 194, 345, 52, '#FDEEE9', '#E8705533', 12, false);
    makeText(ab, 'Offline mode: scanning works, sync pending.', 40, 210, 290, 24, 'caption', 'left').style.textColor = COLORS.coral;
    addListCard(ab, 24, 260, 345, 92, 'Pending Upload', 'Dinosaur Pizza • 1:12 PM', 'Retry');
    addListCard(ab, 24, 364, 345, 92, 'Pending Upload', 'Rainbow Castle • 1:16 PM', 'Queued');
    makeRect(ab, 24, 472, 345, 92, COLORS.white, '#1F232822', 16, true);
    makeText(ab, 'Network Restored', 40, 498, 220, 24, 'headline', 'left');
    makeText(ab, 'Tap to sync all pending artwork.', 40, 526, 250, 24, 'body', 'left');
    addPrimaryButton(ab, 'Retry Sync', 700, COLORS.coral);
    addTabBar(ab, screen.tab);
  }
}

function buildIPadScreen(ab, name, subtitle, kind) {
  var w = ab.frame.width;
  var h = ab.frame.height;

  setArtboardBackground(ab);
  makeRect(ab, 0, 0, w, h, COLORS.paper, null, 0, false);

  makeRect(ab, 0, 0, w, 86, '#F9F5ED', '#1F232811', 0, false);
  makeRect(ab, 32, 20, 48, 48, COLORS.sky, null, 24, false);
  makeText(ab, 'AK', 32, 32, 48, 24, 'button', 'center');
  makeText(ab, name, 94, 24, 460, 34, 'title', 'left');
  makeText(ab, subtitle, 94, 56, 560, 20, 'caption', 'left');

  if (kind === 'split') {
    makeRect(ab, 32, 110, 300, h - 142, COLORS.white, '#1F232822', 20, true);
    addListCard(ab, 48, 136, 268, 92, 'Recent Masterpieces', 'Grouped by child age', null);
    addListCard(ab, 48, 240, 268, 92, 'Family Activity', 'Comments and stickers', null);
    makeRect(ab, 348, 110, w - 380, h - 142, '#F2E8D8', '#1F232822', 20, true);
    makeText(ab, 'Detail Panel', 372, 136, 260, 24, 'headline', 'left');
  } else if (kind === 'capture') {
    makeRect(ab, 32, 110, w - 396, h - 142, '#2B2B2E', null, 24, true);
    makeRect(ab, 58, 136, w - 448, h - 230, '#17181B', '#FFFFFF33', 18, false);
    makeRect(ab, w - 344, 110, 312, h - 142, COLORS.white, '#1F232822', 20, true);
    makeText(ab, 'Scan Tools', w - 320, 136, 220, 24, 'headline', 'left');
    addListCard(ab, w - 320, 172, 264, 72, 'Mode', 'Auto crop + deskew', null);
    addListCard(ab, w - 320, 256, 264, 72, 'Color', 'Shadow cleanup on', null);
    addListCard(ab, w - 320, 340, 264, 72, 'Output', 'High quality preview', null);
  } else if (kind === 'timeline') {
    makeRect(ab, 32, 110, w - 64, h - 142, COLORS.white, '#1F232822', 20, true);
    makeRect(ab, 52, 136, (w - 112) / 2, h - 194, '#F2E8D8', '#1F232822', 16, false);
    makeRect(ab, 68, 154, (w - 160) / 2, h - 230, COLORS.white, '#1F232822', 12, false);
    makeText(ab, 'Timeline Column', 72, 168, 220, 22, 'headline', 'left');
    makeRect(ab, (w / 2) + 8, 136, (w - 112) / 2, h - 194, '#F2E8D8', '#1F232822', 16, false);
    makeRect(ab, (w / 2) + 24, 154, (w - 160) / 2, h - 230, COLORS.white, '#1F232822', 12, false);
    makeText(ab, 'Preview / Metadata', (w / 2) + 28, 168, 240, 22, 'headline', 'left');
  } else if (kind === 'shop') {
    makeRect(ab, 32, 110, 320, h - 142, COLORS.white, '#1F232822', 20, true);
    makeText(ab, 'Products', 56, 138, 180, 24, 'headline', 'left');
    addListCard(ab, 56, 176, 272, 74, 'Mugs', 'Ceramic + glossy', null);
    addListCard(ab, 56, 262, 272, 74, 'Cards', 'Premium matte sets', null);
    addListCard(ab, 56, 348, 272, 74, 'Yearbook', 'Hardcover layout', null);
    makeRect(ab, 368, 110, w - 400, h - 142, '#F2E8D8', '#1F232822', 20, true);
    makeText(ab, 'Customization Canvas', 392, 138, 280, 24, 'headline', 'left');
    makeRect(ab, 392, 176, w - 448, h - 260, COLORS.white, '#1F232822', 16, false);
  } else if (kind === 'settings') {
    makeRect(ab, 32, 110, 320, h - 142, COLORS.white, '#1F232822', 20, true);
    addListCard(ab, 56, 136, 272, 74, 'General', 'Profile, notifications, privacy', null);
    addListCard(ab, 56, 222, 272, 74, 'Subscription', 'Curator plan and billing', null);
    addListCard(ab, 56, 308, 272, 74, 'Data', 'Export and backups', null);
    makeRect(ab, 368, 110, w - 400, h - 142, COLORS.white, '#1F232822', 20, true);
    makeText(ab, 'Detail Settings Pane', 392, 138, 280, 24, 'headline', 'left');
    addListCard(ab, 392, 176, w - 448, 84, 'Invite-only sharing', 'Enabled for all family posts', 'On');
    addListCard(ab, 392, 272, w - 448, 84, 'Mic permissions', 'Allow voice memo attachments', 'On');
  }
}

function addFlowHotspot(source, target) {
  if (!source || !target) {
    return;
  }
  new HotSpot({
    parent: source,
    frame: new Rectangle(305, 58, 64, 32),
    flow: {
      target: target,
      animationType: 'slideFromRight'
    }
  });
}

var doc = new Document();
var pageNames = [
  '00 Cover & Notes',
  '01 Foundations',
  '02 Components',
  '03 iPhone Flows',
  '04 iPad Flows',
  '05 Prototype Links',
  '06 Handoff Specs'
];

var pages = {};
var pageList = [];
for (var p = 0; p < pageNames.length; p += 1) {
  var page = new Page({ name: pageNames[p] });
  pageList.push(page);
  pages[pageNames[p]] = page;
}
doc.pages = pageList;

// 00 Cover & Notes
var coverPage = pages['00 Cover & Notes'];
var cover = new Artboard({
  name: 'ArtKeep Cover',
  parent: coverPage,
  frame: new Rectangle(0, 0, 1194, 834)
});
setArtboardBackground(cover);
makeRect(cover, 0, 0, 1194, 834, COLORS.paper, null, 0, false);
makeRect(cover, 82, 72, 1030, 690, '#F2E8D8', '#1F232822', 36, true);
makeRect(cover, 132, 120, 140, 140, COLORS.coral, null, 42, false);
makeText(cover, 'AK', 132, 168, 140, 48, 'display', 'center').style.textColor = COLORS.white;
makeText(cover, 'ArtKeep', 300, 132, 420, 76, 'display', 'left');
makeText(cover, 'A private, permanent digital gallery for children\'s artwork.', 300, 206, 620, 44, 'headline', 'left');
makeRect(cover, 300, 286, 680, 190, COLORS.white, '#1F232822', 22, true);
makeText(cover, 'Core Problem: The Guilt Pile\nParents receive endless drawings, run out of space, and feel guilty discarding memories.', 332, 324, 620, 80, 'body', 'left');
makeText(cover, 'Solution: AI scanner + timeline tagging + private virtual fridge + voice memories + print upsells.', 332, 398, 620, 58, 'body', 'left');
makeRect(cover, 300, 496, 680, 206, COLORS.white, '#1F232822', 22, true);
makeText(cover, 'Deliverables in this file', 332, 528, 280, 28, 'headline', 'left');
makeText(cover, '• Full iPhone and iPad flows\n• Component library and variants\n• Clickable prototype links\n• Handoff specs, tokens, and QA criteria', 332, 560, 560, 96, 'body', 'left');

// 01 Foundations
var foundationsPage = pages['01 Foundations'];
var tokenSheet = new Artboard({
  name: 'Token Sheet',
  parent: foundationsPage,
  frame: new Rectangle(0, 0, 834, 1194)
});
setArtboardBackground(tokenSheet);
makeRect(tokenSheet, 0, 0, 834, 1194, COLORS.paper, null, 0, false);
makeText(tokenSheet, 'ArtKeep Foundations', 40, 40, 420, 46, 'display', 'left');
makeText(tokenSheet, 'Warm scrapbook-premium style for iOS 17+.', 40, 92, 460, 24, 'body', 'left');

makeRect(tokenSheet, 40, 140, 754, 250, COLORS.white, '#1F232822', 24, true);
makeText(tokenSheet, 'Color Tokens', 64, 166, 220, 28, 'headline', 'left');
var swatches = [
  ['Ink', COLORS.ink],
  ['Paper', COLORS.paper],
  ['Coral', COLORS.coral],
  ['Sage', COLORS.sage],
  ['Sky', COLORS.sky],
  ['Sand', COLORS.sand]
];
var swx = 64;
for (var s = 0; s < swatches.length; s += 1) {
  makeRect(tokenSheet, swx, 214, 110, 110, swatches[s][1], '#1F232822', 14, false);
  makeText(tokenSheet, swatches[s][0], swx, 330, 110, 18, 'caption', 'center');
  makeText(tokenSheet, swatches[s][1], swx, 348, 110, 18, 'mono', 'center');
  swx += 118;
}

makeRect(tokenSheet, 40, 416, 754, 220, COLORS.white, '#1F232822', 24, true);
makeText(tokenSheet, 'Typography', 64, 442, 220, 28, 'headline', 'left');
makeText(tokenSheet, 'Display • New York 34/40', 64, 486, 340, 36, 'display', 'left');
makeText(tokenSheet, 'Title • New York 27/33', 64, 530, 340, 32, 'title', 'left');
makeText(tokenSheet, 'Body • SF Pro Text 15/21', 64, 570, 340, 28, 'body', 'left');
makeText(tokenSheet, 'Caption • SF Pro Text 12/16', 64, 606, 340, 24, 'caption', 'left');

makeRect(tokenSheet, 40, 662, 754, 216, COLORS.white, '#1F232822', 24, true);
makeText(tokenSheet, 'Spacing & Layout', 64, 688, 280, 28, 'headline', 'left');
makeText(tokenSheet, '4pt base grid • 8pt rhythm • 16pt iPhone padding • 32pt iPad padding', 64, 726, 620, 28, 'body', 'left');
makeRect(tokenSheet, 64, 770, 700, 12, '#EFE8DA', null, 6, false);
for (var g = 0; g < 8; g += 1) {
  makeRect(tokenSheet, 64 + (g * 88), 802, 64, 64, '#F2E8D8', '#1F232822', 8, false);
  makeText(tokenSheet, String((g + 1) * 8) + 'pt', 64 + (g * 88), 870, 64, 18, 'caption', 'center');
}

makeRect(tokenSheet, 40, 904, 754, 250, COLORS.white, '#1F232822', 24, true);
makeText(tokenSheet, 'Accessibility Baseline (WCAG AA)', 64, 930, 360, 28, 'headline', 'left');
makeText(tokenSheet, '• Minimum 44x44pt touch targets\n• Contrast-checked foreground/background pairs\n• Dynamic Type-safe layout with 30-40% copy expansion\n• Voice memo and scanner states include permission fallback messaging', 64, 968, 650, 140, 'body', 'left');

var typographyArtboard = new Artboard({
  name: 'Foundations - Grid & Accessibility',
  parent: foundationsPage,
  frame: new Rectangle(914, 0, 834, 1194)
});
setArtboardBackground(typographyArtboard);
makeRect(typographyArtboard, 0, 0, 834, 1194, COLORS.paper, null, 0, false);
makeText(typographyArtboard, 'Grid Reference', 40, 40, 320, 40, 'title', 'left');
for (var row = 0; row < 12; row += 1) {
  makeRect(typographyArtboard, 40, 100 + (row * 80), 754, 1, '#1F232811', null, 0, false);
}
for (var col = 0; col < 8; col += 1) {
  makeRect(typographyArtboard, 40 + (col * 94), 100, 1, 940, '#1F232811', null, 0, false);
}
makeRect(typographyArtboard, 40, 1060, 754, 94, COLORS.white, '#1F232822', 16, true);
makeText(typographyArtboard, 'Device Targets: iPhone 393x852, iPad 834x1194 & 1194x834', 64, 1094, 640, 28, 'body', 'left');

// 02 Components
var componentsPage = pages['02 Components'];
makeText(new Artboard({
  name: 'Components Header',
  parent: componentsPage,
  frame: new Rectangle(0, 0, 1200, 180)
}), 'ArtKeep Components & Variants', 40, 56, 620, 52, 'display', 'left');

var componentNames = [
  'AppBar/Default',
  'TabBar/5-Item',
  'SegmentedControl/2-Item',
  'Chip/Default',
  'Pill/Count',
  'ArtworkCard/Compact',
  'ArtworkCard/Detailed',
  'ArtworkCard/PremiumBadge',
  'ArtworkCard/Watermark',
  'AgeTag/Auto',
  'AgeTag/Edited',
  'AgeTag/Hidden',
  'FridgePostCard/Comments',
  'FridgePostCard/Stickers',
  'FridgePostCard/Private',
  'CaptureToolbar/Auto',
  'CaptureToolbar/Manual',
  'CaptureToolbar/LowLight',
  'VoiceMemoControl/Idle',
  'VoiceMemoControl/Recording',
  'VoiceMemoControl/Playback',
  'VoiceMemoControl/PermissionDenied',
  'StorageMeter/Normal',
  'StorageMeter/Warning',
  'StorageMeter/HardLimit',
  'PaywallCard/Monthly',
  'PaywallCard/Annual',
  'PaywallCard/Selected',
  'PaywallCard/Trial',
  'PrintProductCard/Mug',
  'PrintProductCard/Card',
  'PrintProductCard/Shirt',
  'PrintProductCard/Yearbook',
  'Modal/Action',
  'Sheet/Confirmation',
  'State/Empty',
  'State/Error',
  'State/Loading'
];

var baseX = 0;
var baseY = 240;
var itemW = 360;
var itemH = 120;
var gapX = 52;
var gapY = 44;
for (var c = 0; c < componentNames.length; c += 1) {
  var colIndex = c % 3;
  var rowIndex = Math.floor(c / 3);
  var sxm = baseX + (colIndex * (itemW + gapX));
  var sym = baseY + (rowIndex * (itemH + gapY));
  var symbol = new SymbolMaster({
    name: componentNames[c],
    parent: componentsPage,
    frame: new Rectangle(sxm, sym, itemW, itemH)
  });
  makeRect(symbol, 0, 0, itemW, itemH, COLORS.white, '#1F232822', 18, true);
  makeRect(symbol, 16, 16, 56, 56, '#F2E8D8', null, 12, false);
  makeText(symbol, componentNames[c], 84, 24, itemW - 100, 26, 'headline', 'left');
  makeText(symbol, 'Variant preview', 84, 56, itemW - 100, 20, 'caption', 'left');
}

var iconNames = ['Icon-Home', 'Icon-Capture', 'Icon-Timeline', 'Icon-Fridge', 'Icon-Shop', 'Icon-Comment', 'Icon-Sticker', 'Icon-Print'];
var iconX = 0;
var iconY = baseY + (Math.ceil(componentNames.length / 3) * (itemH + gapY)) + 120;
for (var ic = 0; ic < iconNames.length; ic += 1) {
  var iconBoard = new Artboard({
    name: iconNames[ic],
    parent: componentsPage,
    frame: new Rectangle(iconX, iconY, 96, 96)
  });
  setArtboardBackground(iconBoard);
  makeRect(iconBoard, 0, 0, 96, 96, COLORS.white, '#1F232822', 18, false);
  makeRect(iconBoard, 22, 18, 52, 52, '#F2E8D8', null, 14, false);
  makeText(iconBoard, iconNames[ic].replace('Icon-', '').substring(0, 1), 22, 34, 52, 24, 'headline', 'center');
  iconX += 118;
}

var componentsNote = new Artboard({
  name: 'Components Notes',
  parent: componentsPage,
  frame: new Rectangle(0, iconY + 150, 1194, 240)
});
setArtboardBackground(componentsNote);
makeRect(componentsNote, 0, 0, 1194, 240, COLORS.paper, null, 0, false);
makeRect(componentsNote, 24, 24, 1146, 192, COLORS.white, '#1F232822', 20, true);
makeText(componentsNote, 'Component Set Includes all requested variants for cards, tags, controls, paywall, print products, and state templates.', 48, 74, 1080, 60, 'body', 'left');
makeText(componentsNote, 'These Symbol Masters can be detached or overridden for high-fidelity production screen assembly.', 48, 136, 1080, 40, 'caption', 'left');

// 03 iPhone Flows
var iphonePage = pages['03 iPhone Flows'];
var iPhoneScreens = [
  { key: '01 Splash', title: 'ArtKeep', subtitle: 'A private home for every masterpiece', kind: 'splash', tab: null },
  { key: '02 Onboarding - Emotional Value', title: 'Keep Every Masterpiece', subtitle: 'Preserve memories without the guilt pile.', kind: 'onboarding', tab: null },
  { key: '03 Onboarding - AI Scanner', title: 'Scan Like a Pro', subtitle: 'Auto-crop, de-skew, and color-correct drawings.', kind: 'onboarding', tab: null },
  { key: '04 Onboarding - Virtual Fridge', title: 'Share Privately', subtitle: 'Invite-only family feed with comments and stickers.', kind: 'onboarding', tab: null },
  { key: '05 Child Setup - Name & DOB', title: 'Create Child Profile', subtitle: 'Used for timeline age tagging.', kind: 'setup', tab: null },
  { key: '06 Child Setup - Avatar & Color', title: 'Pick Avatar Style', subtitle: 'Personalize cards and age tags.', kind: 'setup', tab: null },
  { key: '07 Permissions Hub', title: 'Permissions Setup', subtitle: 'Camera, mic, photos, and notifications.', kind: 'permissions', tab: null },
  { key: '08 Paywall - Early Offer', title: 'Unlock Curator Mode', subtitle: 'Unlimited cloud archive and high-res downloads.', kind: 'paywall', tab: null },
  { key: '09 Paywall - Plan Compare', title: 'Plan Comparison', subtitle: 'Free vs Curator feature breakdown.', kind: 'paywall', tab: null },
  { key: '10 First Success CTA', title: 'Ready to Start', subtitle: 'Let\'s scan your first artwork.', kind: 'cta', tab: null },
  { key: '11 Home Dashboard', title: 'Home', subtitle: 'Recent pieces, usage, and seasonal prompts.', kind: 'dashboard', tab: 'Home' },
  { key: '12 Capture - Live Scanner', title: 'Capture', subtitle: 'AI scanner tuned for children\'s art.', kind: 'capture', tab: 'Capture' },
  { key: '13 Capture - Auto Crop', title: 'Auto Crop Review', subtitle: 'Confirm framing before save.', kind: 'editor', tab: 'Capture' },
  { key: '14 Capture - Manual Adjust', title: 'Manual Adjust', subtitle: 'Fine-tune corners and perspective.', kind: 'editor', tab: 'Capture' },
  { key: '15 Capture - Enhance Preview', title: 'Enhance Preview', subtitle: 'Before/after cleanup and color restore.', kind: 'editor', tab: 'Capture' },
  { key: '16 Save Metadata', title: 'Save Details', subtitle: 'Title, child, date, and medium.', kind: 'metadata', tab: 'Capture' },
  { key: '17 Voice Memo Attach', title: 'Attach Voice Memo', subtitle: 'Record your child\'s story about the drawing.', kind: 'voice', tab: 'Capture' },
  { key: '18 Save Success - Post to Fridge', title: 'Saved!', subtitle: 'Post to your private virtual fridge.', kind: 'success', tab: 'Capture' },
  { key: '19 Timeline - Month List', title: 'Timeline', subtitle: 'Organized by month and year.', kind: 'timeline', tab: 'Timeline' },
  { key: '20 Timeline - Age Grouped', title: 'Age Timeline', subtitle: 'Noah • 4 years, 2 months.', kind: 'timeline', tab: 'Timeline' },
  { key: '21 Artwork Detail', title: 'Artwork Detail', subtitle: 'View full piece with metadata.', kind: 'detail', tab: 'Timeline' },
  { key: '22 Artwork Comments', title: 'Family Comments', subtitle: 'Private reactions from invited members.', kind: 'comments', tab: 'Timeline' },
  { key: '23 Sticker Picker', title: 'Sticker Reactions', subtitle: 'Grandparents can send quick delight.', kind: 'sticker', tab: 'Timeline' },
  { key: '24 Search Filter Sort', title: 'Search & Filters', subtitle: 'Find artwork by age, date, or favorites.', kind: 'filter', tab: 'Timeline' },
  { key: '25 Family Fridge Feed', title: 'Virtual Fridge', subtitle: 'Private family feed of new uploads.', kind: 'fridge', tab: 'Fridge' },
  { key: '26 Family Invite', title: 'Invite Family', subtitle: 'Add grandparents and close relatives.', kind: 'invite', tab: 'Fridge' },
  { key: '27 Invite Acceptance & Role', title: 'Invite Roles', subtitle: 'Viewer vs commenter permissions.', kind: 'invite', tab: 'Fridge' },
  { key: '28 Notifications Center', title: 'Notifications', subtitle: 'Comments, stickers, and seasonal prompts.', kind: 'notifications', tab: 'Fridge' },
  { key: '29 Shop Hub', title: 'Print Shop', subtitle: 'Turn art into keepsakes and gifts.', kind: 'shop', tab: 'Shop' },
  { key: '30 Product Customization', title: 'Customize Product', subtitle: 'Crop, variant, quantity, personalization.', kind: 'shop', tab: 'Shop' },
  { key: '31 Cart', title: 'Cart', subtitle: 'Review selected print items.', kind: 'cart', tab: 'Shop' },
  { key: '32 Checkout', title: 'Checkout', subtitle: 'Shipping, payment, and confirmation.', kind: 'checkout', tab: 'Shop' },
  { key: '33 Order Confirmation', title: 'Order Confirmed', subtitle: 'Your keepsake is now in production.', kind: 'confirmation', tab: 'Shop' },
  { key: '34 Holiday Campaign Modal', title: 'Seasonal Campaign', subtitle: 'Mother\'s Day / Christmas conversion prompt.', kind: 'modal', tab: 'Shop' },
  { key: '35 Storage Meter (0-49)', title: 'Storage Overview', subtitle: 'Free tier usage before hard limit.', kind: 'storage', tab: 'Home' },
  { key: '36 50 Item Limit Upsell', title: 'Limit Reached', subtitle: 'Upgrade to Curator for unlimited archive.', kind: 'upsell', tab: 'Timeline' },
  { key: '37 Watermarked Download Modal', title: 'Watermarked Download', subtitle: 'High-res non-watermarked requires Curator.', kind: 'modal', tab: 'Timeline' },
  { key: '38 Curator Subscription Management', title: 'Subscription', subtitle: 'Manage plan and entitlements.', kind: 'subscription', tab: 'Shop' },
  { key: '39 Multi-Child Profiles (Paid)', title: 'Multi-Child Profiles', subtitle: 'Manage multiple child timelines.', kind: 'profiles', tab: 'Shop' },
  { key: '40 Settings & Privacy', title: 'Settings & Privacy', subtitle: 'Invite controls, export, legal, account.', kind: 'settings', tab: 'Shop' },
  { key: '41 Error & Empty States', title: 'State Library', subtitle: 'Empty, error, and loading patterns.', kind: 'states', tab: 'Shop' },
  { key: '42 Offline & Retry States', title: 'Offline Handling', subtitle: 'Queue captures and retry sync.', kind: 'offline', tab: 'Shop' }
];

var iphoneArtboards = {};
var iPhoneWidth = 393;
var iPhoneHeight = 852;
var iGapX = 120;
var iGapY = 140;
for (var i = 0; i < iPhoneScreens.length; i += 1) {
  var col = i % 4;
  var row = Math.floor(i / 4);
  var iAb = new Artboard({
    name: iPhoneScreens[i].key,
    parent: iphonePage,
    frame: new Rectangle(col * (iPhoneWidth + iGapX), row * (iPhoneHeight + iGapY), iPhoneWidth, iPhoneHeight)
  });
  buildIPhoneScreen(iAb, iPhoneScreens[i]);
  iphoneArtboards[iPhoneScreens[i].key] = iAb;
}

// 04 iPad Flows
var ipadPage = pages['04 iPad Flows'];
var ipadScreens = [
  { key: 'iPad 01 Home Split Layout', subtitle: 'Primary dashboard + secondary detail pane', kind: 'split', w: 834, h: 1194 },
  { key: 'iPad 02 Capture Canvas + Tools', subtitle: 'Large scan area with side controls', kind: 'capture', w: 1194, h: 834 },
  { key: 'iPad 03 Timeline Two-Column', subtitle: 'Timeline and preview side-by-side', kind: 'timeline', w: 834, h: 1194 },
  { key: 'iPad 04 Artwork Detail + Comments', subtitle: 'Persistent comments with detail preview', kind: 'split', w: 1194, h: 834 },
  { key: 'iPad 05 Fridge Feed + Thread', subtitle: 'Feed list and discussion pane', kind: 'split', w: 1194, h: 834 },
  { key: 'iPad 06 Shop Customize Expanded', subtitle: 'Category rail + product canvas', kind: 'shop', w: 1194, h: 834 },
  { key: 'iPad 07 Onboarding Condensed', subtitle: 'Compact onboarding adapted to tablet', kind: 'split', w: 834, h: 1194 },
  { key: 'iPad 08 Paywall iPad', subtitle: 'Feature comparison with premium emphasis', kind: 'shop', w: 834, h: 1194 },
  { key: 'iPad 09 Settings Multi-Pane', subtitle: 'Section list with configurable details', kind: 'settings', w: 1194, h: 834 },
  { key: 'iPad 10 Multi-Child Management Board', subtitle: 'Board-style child profile management', kind: 'timeline', w: 834, h: 1194 }
];

var ipadX = 0;
var ipadY = 0;
var ipadRowMax = 0;
for (var ip = 0; ip < ipadScreens.length; ip += 1) {
  var spec = ipadScreens[ip];
  if (ipadX + spec.w > 3000) {
    ipadX = 0;
    ipadY += ipadRowMax + 160;
    ipadRowMax = 0;
  }
  var iPadAb = new Artboard({
    name: spec.key,
    parent: ipadPage,
    frame: new Rectangle(ipadX, ipadY, spec.w, spec.h)
  });
  buildIPadScreen(iPadAb, spec.key, spec.subtitle, spec.kind);
  ipadX += spec.w + 140;
  if (spec.h > ipadRowMax) {
    ipadRowMax = spec.h;
  }
}

// 05 Prototype Links
var prototypePage = pages['05 Prototype Links'];
var flowCards = [
  {
    title: 'Flow 01 • Onboarding to Fridge',
    steps: 'Onboarding -> Setup -> Permissions -> Early Paywall -> First Scan -> Voice Memo -> Post to Fridge',
    start: '02 Onboarding - Emotional Value'
  },
  {
    title: 'Flow 02 • Home to Timeline Detail',
    steps: 'Home -> Capture -> Enhance -> Save -> Timeline -> Detail',
    start: '11 Home Dashboard'
  },
  {
    title: 'Flow 03 • Family Social Loop',
    steps: 'Notifications -> Virtual Fridge -> Sticker Picker -> Comments',
    start: '28 Notifications Center'
  },
  {
    title: 'Flow 04 • Limit to Subscription',
    steps: 'Storage Limit Upsell -> Curator Subscription Management',
    start: '36 50 Item Limit Upsell'
  },
  {
    title: 'Flow 05 • Timeline to Checkout',
    steps: 'Timeline -> Artwork Detail -> Shop -> Customize -> Cart -> Checkout -> Confirmation',
    start: '20 Timeline - Age Grouped'
  }
];

for (var f = 0; f < flowCards.length; f += 1) {
  var fx = (f % 2) * 520;
  var fy = Math.floor(f / 2) * 420;
  var fAb = new Artboard({
    name: flowCards[f].title,
    parent: prototypePage,
    frame: new Rectangle(fx, fy, 480, 360)
  });
  setArtboardBackground(fAb);
  makeRect(fAb, 0, 0, 480, 360, COLORS.paper, null, 0, false);
  makeRect(fAb, 24, 24, 432, 312, COLORS.white, '#1F232822', 20, true);
  makeText(fAb, flowCards[f].title, 44, 50, 380, 42, 'headline', 'left');
  makeText(fAb, flowCards[f].steps, 44, 106, 380, 108, 'body', 'left');
  makeRect(fAb, 44, 250, 188, 48, COLORS.coral, null, 16, false);
  makeText(fAb, 'Start Flow', 44, 264, 188, 20, 'button', 'center').style.textColor = COLORS.white;
  if (iphoneArtboards[flowCards[f].start]) {
    new HotSpot({
      parent: fAb,
      frame: new Rectangle(44, 250, 188, 48),
      flow: {
        target: iphoneArtboards[flowCards[f].start],
        animationType: 'slideFromRight'
      }
    });
  }
}

// 06 Handoff Specs
var handoffPage = pages['06 Handoff Specs'];
var modelsAb = new Artboard({
  name: 'Handoff - Public Interfaces & Routes',
  parent: handoffPage,
  frame: new Rectangle(0, 0, 1194, 834)
});
setArtboardBackground(modelsAb);
makeRect(modelsAb, 0, 0, 1194, 834, COLORS.paper, null, 0, false);
makeRect(modelsAb, 24, 24, 1146, 786, COLORS.white, '#1F232822', 24, true);
makeText(modelsAb, 'Public Interfaces / Types', 48, 52, 380, 34, 'title', 'left');
makeText(modelsAb,
  'ChildProfile: id, name, birthDate, avatar, themeColor\n' +
  'Artwork: id, childId, capturedAt, title, ageTag, imageUrl, enhancedImageUrl, voiceMemoUrl, isWatermarked, isFavorite\n' +
  'FridgePost: id, artworkId, sharedAt, audienceIds, stickerReactions, comments\n' +
  'SubscriptionState: plan, artworkCount, artworkLimit, multiChildEnabled, highResEnabled\n' +
  'PrintOrderDraft: artworkId, productType, variant, quantity, personalization, shippingAddress',
  48, 100, 1080, 224, 'body', 'left'
);
makeRect(modelsAb, 48, 338, 1098, 184, '#F2E8D8', '#1F232822', 16, false);
makeText(modelsAb, 'Route Map', 68, 360, 220, 24, 'headline', 'left');
makeText(modelsAb,
  '/onboarding/*\n/capture/*\n/timeline/*\n/fridge/*\n/shop/*\n/paywall\n/settings',
  68, 392, 240, 128, 'mono', 'left'
);
makeText(modelsAb, 'Sharing is private-by-default and invite-only.\nPrint flow is provider-agnostic (Printful/Gelato compatible model).', 370, 392, 720, 92, 'body', 'left');

var qaAb = new Artboard({
  name: 'Handoff - QA Scenarios',
  parent: handoffPage,
  frame: new Rectangle(0, 920, 1194, 834)
});
setArtboardBackground(qaAb);
makeRect(qaAb, 0, 0, 1194, 834, COLORS.paper, null, 0, false);
makeRect(qaAb, 24, 24, 1146, 786, COLORS.white, '#1F232822', 24, true);
makeText(qaAb, 'Acceptance Scenarios', 48, 52, 380, 34, 'title', 'left');
makeText(qaAb,
  '1. First-time user reaches successful scan under 2 minutes.\n' +
  '2. Scanner clearly communicates auto-crop, de-skew, and enhancement states.\n' +
  '3. Age tags auto-generate from DOB + capture date.\n' +
  '4. Invite flow prevents public sharing by default.\n' +
  '5. Voice memo permission denial has clear recovery CTA.\n' +
  '6. Free tier shows 0-49 meter and hard gate at 50 with upsell.\n' +
  '7. Paid state removes watermark cues and unlocks multi-child management.\n' +
  '8. Shop supports mug, card, t-shirt, yearbook products.\n' +
  '9. Layout remains stable under 30-40% copy expansion.\n' +
  '10. Contrast and touch targets satisfy WCAG AA baseline.',
  48, 106, 1040, 520, 'body', 'left'
);
makeRect(qaAb, 48, 652, 1098, 120, '#EEF4F0', '#7FAE8D44', 16, false);
makeText(qaAb, 'Assumptions: Light mode first, English-first copy, iOS 17+ conventions, no pre-existing brand assets required.', 68, 694, 980, 44, 'body', 'left');

var exportAb = new Artboard({
  name: 'Handoff - Export Manifest',
  parent: handoffPage,
  frame: new Rectangle(1220, 0, 834, 834)
});
setArtboardBackground(exportAb);
makeRect(exportAb, 0, 0, 834, 834, COLORS.paper, null, 0, false);
makeRect(exportAb, 24, 24, 786, 786, COLORS.white, '#1F232822', 24, true);
makeText(exportAb, 'Engineering Export Set', 48, 52, 360, 34, 'title', 'left');
makeText(exportAb,
  'Icons (SVG/PDF):\nIcon-Home, Icon-Capture, Icon-Timeline, Icon-Fridge, Icon-Shop, Icon-Comment, Icon-Sticker, Icon-Print\n\n' +
  'Raster Placeholders (PNG @2x/@3x):\n11 Home Dashboard\n12 Capture - Live Scanner\n20 Timeline - Age Grouped\n25 Family Fridge Feed\n29 Shop Hub\n\n' +
  'Tokens:\nToken Sheet (PDF/PNG)',
  48, 104, 700, 460, 'body', 'left'
);
makeRect(exportAb, 48, 590, 738, 180, '#F2E8D8', '#1F232822', 16, false);
makeText(exportAb, 'This file is fully editable in Sketch with symbol masters and linked prototype hotspots.', 68, 652, 680, 54, 'body', 'left');

// Prototype wiring across iPhone screens
var flowPairs = [
  ['02 Onboarding - Emotional Value', '03 Onboarding - AI Scanner'],
  ['03 Onboarding - AI Scanner', '04 Onboarding - Virtual Fridge'],
  ['04 Onboarding - Virtual Fridge', '05 Child Setup - Name & DOB'],
  ['05 Child Setup - Name & DOB', '06 Child Setup - Avatar & Color'],
  ['06 Child Setup - Avatar & Color', '07 Permissions Hub'],
  ['07 Permissions Hub', '08 Paywall - Early Offer'],
  ['08 Paywall - Early Offer', '09 Paywall - Plan Compare'],
  ['09 Paywall - Plan Compare', '10 First Success CTA'],
  ['10 First Success CTA', '12 Capture - Live Scanner'],
  ['12 Capture - Live Scanner', '13 Capture - Auto Crop'],
  ['13 Capture - Auto Crop', '14 Capture - Manual Adjust'],
  ['14 Capture - Manual Adjust', '15 Capture - Enhance Preview'],
  ['15 Capture - Enhance Preview', '16 Save Metadata'],
  ['16 Save Metadata', '17 Voice Memo Attach'],
  ['17 Voice Memo Attach', '18 Save Success - Post to Fridge'],
  ['18 Save Success - Post to Fridge', '25 Family Fridge Feed'],
  ['11 Home Dashboard', '12 Capture - Live Scanner'],
  ['28 Notifications Center', '25 Family Fridge Feed'],
  ['25 Family Fridge Feed', '23 Sticker Picker'],
  ['23 Sticker Picker', '22 Artwork Comments'],
  ['36 50 Item Limit Upsell', '38 Curator Subscription Management'],
  ['20 Timeline - Age Grouped', '21 Artwork Detail'],
  ['21 Artwork Detail', '29 Shop Hub'],
  ['29 Shop Hub', '30 Product Customization'],
  ['30 Product Customization', '31 Cart'],
  ['31 Cart', '32 Checkout'],
  ['32 Checkout', '33 Order Confirmation']
];

for (var fp = 0; fp < flowPairs.length; fp += 1) {
  addFlowHotspot(iphoneArtboards[flowPairs[fp][0]], iphoneArtboards[flowPairs[fp][1]]);
}

if (iphoneArtboards['02 Onboarding - Emotional Value']) {
  iphoneArtboards['02 Onboarding - Emotional Value'].flowStartPoint = true;
}
if (iphoneArtboards['11 Home Dashboard']) {
  iphoneArtboards['11 Home Dashboard'].flowStartPoint = true;
}
if (iphoneArtboards['28 Notifications Center']) {
  iphoneArtboards['28 Notifications Center'].flowStartPoint = true;
}
if (iphoneArtboards['36 50 Item Limit Upsell']) {
  iphoneArtboards['36 50 Item Limit Upsell'].flowStartPoint = true;
}
if (iphoneArtboards['20 Timeline - Age Grouped']) {
  iphoneArtboards['20 Timeline - Age Grouped'].flowStartPoint = true;
}

try {
  doc.selectedPage = coverPage;
} catch (e) {
  // Non-critical in CLI mode.
}

doc.save(OUTPUT_PATH);
log('Generated Sketch file: ' + OUTPUT_PATH);
