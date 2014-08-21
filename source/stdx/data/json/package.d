/**
 * Package import for the whole std.data.json package.
 *
 * Synopsis:
 * ---
 * // Parse a JSON string
 * JSONValue value = parseJSON(`{"name": "D", "kind": "language"}`);
 * auto fields = value.get!(JSONValue[string]);
 * assert(fields["name"] == "D");
 * assert(fields["kind"] == "language");
 *
 * // Convert a value back to a JSON string
 * assert(value.toJSONString() == `{"name":"D","kind":"language"}`);
 *
 * // Convert a value to a formatted JSON string
 * assert(value.toJSONString!true() ==
 * `{
 *     "name": "D",
 *     "kind": "language"
 * }`);
 *
 * // Lex a JSON string into a lazy range of tokens
 * auto tokens = lexJSON(`{"name": "D", "kind": "language"}`);
 * with (JSONToken.Kind) {
 *     assert(tokens.map!(t => t.kind).equal(
 *         [objectStart, string, colon, string, comma,
 *         string, colon, string, objectEnd]));
 * }
 *
 * // Parse the tokens to a value
 * JSONValue value2 = parseJSON(tokens);
 * assert(value2 == value);
 *
 * // Parse the tokens to a JSON node stream
 * auto nodes = parseJSONStream(tokens);
 * with (JSONParserNode.Kind) {
 *     assert(nodes.map!(n => n.kind).equal(
 *         [objectStart, key, literal, key, literal, objectEnd]));
 * }
 * ---
 *
 * Copyright: Copyright 2012 - 2014, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/package.d)
 */
module stdx.data.json;

public import stdx.data.json.foundation;
public import stdx.data.json.generator;
public import stdx.data.json.lexer;
public import stdx.data.json.parser;
public import stdx.data.json.value;


version (unittest) {
    private enum testString1 =`{
        "cols": [
            "name",
            "num",
            "email",
            "text"
        ],
        "data": [
            [
                "Patrick Kirby",
                "-3.4403043480471",
                "luctus.sit.amet@enim.edu",
                "mauris a nunc. In at pede. Cras vulputate velit eu sem. Pellentesque ut ipsum ac mi eleifend egestas. Sed pharetra, felis eget varius ultrices, mauris ipsum porta elit, a feugiat tellus lorem eu metus. In lorem. Donec elementum, lorem ut aliquam iaculis, lacus pede sagittis augue, eu tempor erat neque non quam. Pellentesque habitant"
            ],
            [
                "Abdul Weaver",
                "1.1076661798338",
                "lorem.eget@placeratCras.com",
                "odio tristique pharetra. Quisque ac libero nec ligula consectetuer rhoncus. Nullam velit dui, semper et, lacinia vitae, sodales at, velit. Pellentesque ultricies dignissim lacus. Aliquam rutrum lorem ac risus. Morbi metus. Vivamus euismod urna. Nullam lobortis quam a felis ullamcorper viverra. Maecenas iaculis aliquet diam. Sed diam lorem, auctor quis, tristique ac, eleifend vitae, erat. Vivamus nisi. Mauris nulla. Integer urna. Vivamus molestie dapibus ligula. Aliquam erat volutpat. Nulla dignissim. Maecenas ornare egestas ligula. Nullam feugiat placerat velit. Quisque varius. Nam porttitor scelerisque neque. Nullam nisl. Maecenas malesuada fringilla"
            ],
            [
                "Reese Calderon",
                "2.9110321408694",
                "Nam.ligula@risus.org",
                "magnis dis parturient montes, nascetur ridiculus mus. Donec dignissim magna a tortor. Nunc commodo"
            ],
            [
                "Philip Stanley",
                "1.5177049910759",
                "adipiscing.fringilla.porttitor@vel.net",
                "dui, in sodales elit erat vitae risus. Duis a mi fringilla mi lacinia mattis. Integer eu lacus. Quisque imperdiet, erat nonummy ultricies ornare, elit elit fermentum risus, at fringilla"
            ],
            [
                "Blaze Hester",
                "-1.5274821664568",
                "est.tempor@turpisAliquamadipiscing.org",
                "egestas. Aliquam nec enim. Nunc ut erat. Sed nunc est, mollis non, cursus non, egestas a, dui. Cras pellentesque. Sed dictum. Proin eget odio. Aliquam vulputate ullamcorper magna. Sed eu eros. Nam"
            ],
            [
                "Kyle Hammond",
                "0.2603162084147",
                "ridiculus.mus.Proin@at.net",
                "elementum, dui quis accumsan convallis, ante lectus convallis est, vitae sodales nisi magna sed dui. Fusce aliquam, enim nec tempus scelerisque, lorem ipsum sodales purus, in molestie tortor nibh sit amet orci. Ut sagittis lobortis mauris. Suspendisse aliquet molestie tellus."
            ],
            [
                "Brennan Petty",
                "-3.4768128125142",
                "Sed.et.libero@consectetuer.org",
                "libero nec ligula consectetuer rhoncus. Nullam velit dui, semper et, lacinia vitae, sodales at, velit. Pellentesque ultricies dignissim lacus. Aliquam rutrum lorem ac risus. Morbi metus. Vivamus euismod urna. Nullam lobortis quam a felis ullamcorper viverra. Maecenas iaculis aliquet diam. Sed diam lorem, auctor quis, tristique ac, eleifend vitae, erat. Vivamus nisi. Mauris nulla. Integer urna. Vivamus molestie dapibus ligula. Aliquam erat volutpat."
            ],
            [
                "Amal Stevenson",
                "0.85198412868279",
                "sed.hendrerit@nunc.com",
                "congue a, aliquet vel, vulputate eu, odio. Phasellus at augue id ante dictum cursus. Nunc mauris elit, dictum eu, eleifend nec, malesuada ut, sem. Nulla interdum. Curabitur dictum. Phasellus in felis. Nulla tempor augue ac ipsum. Phasellus vitae mauris sit amet lorem"
            ],
            [
                "Kibo Levy",
                "-1.4784283166374",
                "convallis@sedpede.com",
                "ultrices. Duis volutpat nunc sit amet metus. Aliquam erat volutpat. Nulla facilisis. Suspendisse commodo tincidunt nibh. Phasellus nulla. Integer vulputate, risus a ultricies adipiscing, enim mi tempor lorem, eget mollis lectus pede et risus. Quisque libero lacus, varius et, euismod et, commodo at, libero. Morbi accumsan laoreet ipsum. Curabitur consequat, lectus sit amet luctus vulputate, nisi sem semper erat, in consectetuer ipsum nunc id enim. Curabitur massa. Vestibulum accumsan neque et nunc. Quisque ornare tortor at risus."
            ],
            [
                "Giacomo Livingston",
                "0.54232248361117",
                "Nullam.vitae.diam@interdumCurabitur.net",
                "egestas. Aliquam nec enim. Nunc ut erat. Sed nunc est, mollis non, cursus non, egestas a, dui. Cras pellentesque. Sed dictum. Proin eget odio. Aliquam vulputate ullamcorper magna. Sed eu eros. Nam consequat dolor vitae dolor. Donec fringilla. Donec feugiat metus sit amet ante. Vivamus non lorem vitae odio sagittis semper. Nam tempor diam dictum sapien. Aenean massa. Integer vitae nibh. Donec est mauris, rhoncus id, mollis nec, cursus a, enim. Suspendisse aliquet, sem ut cursus luctus, ipsum leo elementum sem, vitae aliquam eros turpis non enim. Mauris quis turpis vitae purus gravida"
            ],
            [
                "Ian Gray",
                "-0.18460451694887",
                "lacus.Quisque.purus@tincidunt.edu",
                "interdum ligula eu enim. Etiam imperdiet dictum magna. Ut tincidunt orci quis lectus. Nullam suscipit, est ac facilisis facilisis, magna tellus faucibus leo, in lobortis tellus justo sit amet nulla. Donec non justo. Proin non massa non ante bibendum ullamcorper. Duis cursus, diam at pretium aliquet, metus urna convallis erat, eget tincidunt dui augue eu tellus. Phasellus elit pede, malesuada vel, venenatis vel, faucibus id, libero. Donec consectetuer mauris id sapien. Cras dolor dolor, tempus non, lacinia at, iaculis quis, pede. Praesent eu dui. Cum sociis natoque penatibus et magnis dis"
            ],
            [
                "Salvador Weaver",
                "-1.0306127882055",
                "eu.neque.pellentesque@pulvinar.org",
                "erat eget ipsum. Suspendisse sagittis. Nullam vitae diam. Proin dolor. Nulla semper tellus id nunc interdum feugiat. Sed nec metus facilisis lorem tristique aliquet. Phasellus fermentum convallis ligula. Donec luctus aliquet odio. Etiam ligula tortor, dictum eu, placerat eget, venenatis a, magna. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Etiam laoreet, libero et tristique pellentesque, tellus sem mollis dui, in"
            ],
            [
                "Carson Arnold",
                "2.6606923019535",
                "Cum.sociis@sitametluctus.com",
                "scelerisque, lorem ipsum sodales purus, in molestie tortor nibh sit amet orci. Ut sagittis lobortis mauris. Suspendisse aliquet molestie tellus. Aenean egestas hendrerit neque. In ornare sagittis felis. Donec tempor, est ac mattis semper, dui lectus rutrum urna, nec luctus felis purus ac tellus. Suspendisse sed dolor. Fusce mi lorem, vehicula et, rutrum eu, ultrices sit amet, risus. Donec nibh enim, gravida sit amet, dapibus id, blandit at, nisi. Cum"
            ],
            [
                "Kyle Harvey",
                "-3.988850143986",
                "Fusce.diam.nunc@sit.org",
                "ultricies ligula. Nullam"
            ],
            [
                "Todd Gibbs",
                "0.58497373466655",
                "mattis.semper@maurisanunc.com",
                "erat. Vivamus nisi. Mauris nulla. Integer urna. Vivamus molestie"
            ],
            [
                "Fitzgerald Norris",
                "0.49883579938617",
                "cursus@Inornare.com",
                "sed pede. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Proin vel arcu eu odio tristique pharetra. Quisque ac libero nec ligula consectetuer rhoncus. Nullam velit dui, semper et, lacinia vitae, sodales at, velit. Pellentesque ultricies dignissim lacus. Aliquam rutrum lorem ac risus. Morbi metus. Vivamus euismod urna. Nullam lobortis quam a felis ullamcorper viverra. Maecenas iaculis aliquet diam. Sed diam lorem, auctor quis, tristique ac, eleifend vitae, erat. Vivamus nisi. Mauris nulla. Integer urna. Vivamus"
            ],
            [
                "Amery Hodge",
                "-1.7000203147919",
                "Ut@enim.net",
                "mauris ipsum porta elit, a feugiat tellus lorem eu metus. In lorem. Donec elementum, lorem ut aliquam iaculis, lacus pede sagittis augue, eu tempor erat neque non quam. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aliquam fringilla cursus purus. Nullam scelerisque neque sed sem egestas blandit. Nam nulla magna, malesuada vel, convallis in,"
            ],
            [
                "Todd Kidd",
                "-1.6975579005113",
                "orci@rhoncus.net",
                "Proin non massa non ante bibendum ullamcorper. Duis cursus, diam at pretium aliquet, metus urna convallis erat, eget tincidunt dui augue eu tellus. Phasellus elit pede, malesuada vel, venenatis vel, faucibus id, libero. Donec consectetuer mauris id sapien. Cras dolor dolor, tempus non, lacinia at, iaculis quis, pede. Praesent eu dui. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aenean eget magna. Suspendisse tristique neque venenatis lacus. Etiam bibendum fermentum metus. Aenean sed pede nec ante blandit viverra. Donec tempus, lorem fringilla ornare placerat, orci lacus vestibulum lorem, sit amet"
            ],
            [
                "Xenos Hopper",
                "-2.4634221009688",
                "auctor.ullamcorper.nisl@sollicitudin.com",
                "ultrices sit amet, risus. Donec nibh enim, gravida sit amet, dapibus id, blandit at, nisi. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Proin vel nisl. Quisque fringilla euismod enim. Etiam gravida molestie arcu. Sed eu nibh vulputate mauris sagittis placerat. Cras dictum ultricies ligula. Nullam enim. Sed nulla ante, iaculis nec, eleifend non, dapibus rutrum, justo. Praesent luctus. Curabitur egestas nunc sed libero. Proin"
            ],
            [
                "Hiram Larson",
                "-2.3861602122822",
                "sit.amet@purus.co.uk",
                "non dui nec urna suscipit nonummy. Fusce fermentum fermentum arcu. Vestibulum ante ipsum primis in faucibus orci luctus et"
            ],
            [
                "Timon Grimes",
                "-1.6317122102384",
                "at.risus.Nunc@vitae.org",
                "turpis nec mauris blandit mattis. Cras eget nisi dictum augue malesuada malesuada. Integer id magna et ipsum cursus vestibulum. Mauris magna. Duis dignissim tempor arcu. Vestibulum ut eros non enim commodo hendrerit. Donec porttitor tellus non magna. Nam ligula elit, pretium et, rutrum non, hendrerit id, ante. Nunc mauris sapien, cursus in, hendrerit consectetuer, cursus et, magna. Praesent interdum ligula eu enim. Etiam imperdiet dictum magna. Ut tincidunt orci quis lectus. Nullam suscipit, est ac facilisis facilisis, magna tellus faucibus leo, in lobortis tellus justo sit"
            ],
            [
                "Palmer Bell",
                "0.38641549228268",
                "interdum.enim.non@semperegestas.net",
                "ultricies ornare, elit elit fermentum risus, at fringilla purus mauris a nunc. In at pede. Cras vulputate velit eu sem. Pellentesque ut ipsum ac mi eleifend egestas. Sed pharetra, felis eget varius ultrices, mauris ipsum porta elit, a feugiat tellus lorem eu metus. In lorem. Donec elementum, lorem ut aliquam iaculis, lacus pede sagittis augue, eu tempor erat neque non quam. Pellentesque habitant morbi tristique senectus et netus et malesuada"
            ],
            [
                "Keith Hubbard",
                "1.1787214399064",
                "posuere.at@sitametrisus.edu",
                "Praesent eu dui. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aenean eget magna. Suspendisse tristique neque venenatis lacus. Etiam bibendum fermentum metus. Aenean sed pede nec ante blandit viverra. Donec tempus, lorem fringilla ornare placerat, orci lacus vestibulum lorem, sit amet ultricies sem"
            ],
            [
                "Lars Green",
                "-1.3692547338355",
                "diam.Proin@magnisdisparturient.org",
                "rhoncus. Donec est. Nunc ullamcorper, velit"
            ],
            [
                "Jonas Huff",
                "-0.92361474641041",
                "ipsum.Curabitur@Morbinonsapien.org",
                "consectetuer adipiscing elit. Etiam laoreet, libero et tristique pellentesque, tellus sem mollis dui, in sodales elit erat vitae risus. Duis a mi fringilla mi lacinia mattis. Integer eu lacus. Quisque imperdiet, erat nonummy ultricies ornare, elit elit fermentum risus, at fringilla purus mauris a nunc. In at pede. Cras vulputate velit eu sem. Pellentesque ut ipsum ac mi eleifend egestas. Sed pharetra, felis eget varius ultrices, mauris ipsum porta elit, a feugiat"
            ],
            [
                "Cullen Gaines",
                "0.14272912346868",
                "sociis.natoque.penatibus@dolor.ca",
                "est tempor bibendum. Donec felis orci, adipiscing non, luctus sit amet, faucibus ut, nulla. Cras eu tellus eu augue porttitor interdum. Sed auctor odio a purus. Duis elementum, dui quis accumsan convallis, ante lectus convallis est, vitae sodales nisi magna sed dui. Fusce aliquam, enim nec tempus scelerisque, lorem ipsum sodales purus, in molestie tortor nibh sit amet orci. Ut sagittis lobortis mauris. Suspendisse aliquet"
            ],
            [
                "Tarik Bauer",
                "-4.4274628384424",
                "nisi.Cum.sociis@dictumeleifendnunc.ca",
                "hendrerit. Donec porttitor tellus non magna. Nam ligula elit, pretium et, rutrum non, hendrerit id, ante. Nunc mauris sapien, cursus in, hendrerit consectetuer, cursus et, magna. Praesent interdum ligula eu enim. Etiam imperdiet dictum magna. Ut tincidunt orci quis lectus. Nullam suscipit, est ac facilisis facilisis, magna tellus faucibus leo, in lobortis tellus justo sit amet nulla. Donec non justo. Proin"
            ],
            [
                "Driscoll Robinson",
                "1.6859334536819",
                "Etiam.laoreet.libero@etmalesuada.net",
                "sit amet, dapibus id, blandit at, nisi. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Proin vel nisl. Quisque fringilla euismod enim. Etiam gravida molestie arcu. Sed eu nibh vulputate mauris sagittis placerat. Cras dictum ultricies ligula. Nullam enim. Sed nulla ante, iaculis nec, eleifend non, dapibus rutrum, justo. Praesent luctus. Curabitur egestas nunc sed libero. Proin sed turpis nec mauris blandit mattis. Cras eget nisi dictum augue malesuada malesuada. Integer id magna et ipsum cursus vestibulum."
            ],
            [
                "Lucas Decker",
                "1.4165992895811",
                "sed.dolor@nequesedsem.edu",
                "in faucibus orci luctus et ultrices posuere cubilia Curae; Phasellus ornare. Fusce mollis. Duis sit amet diam eu dolor egestas rhoncus. Proin nisl sem, consequat nec, mollis vitae, posuere at, velit. Cras lorem lorem, luctus ut, pellentesque eget, dictum placerat, augue. Sed molestie. Sed id risus"
            ],
            [
                "Duncan Evans",
                "2.7341570955724",
                "fames.ac.turpis@Morbiaccumsan.ca",
                "Curabitur vel lectus. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec dignissim magna a tortor. Nunc commodo auctor velit. Aliquam nisl. Nulla eu neque pellentesque massa lobortis ultrices. Vivamus rhoncus. Donec est. Nunc ullamcorper, velit in aliquet lobortis, nisi nibh"
            ],
            [
                "Porter Moody",
                "-1.4324173162312",
                "non.hendrerit@litoratorquent.edu",
                "at arcu. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Donec tincidunt. Donec vitae erat vel"
            ],
            [
                "Wade Preston",
                "0.32972666337599",
                "libero@molestieorcitincidunt.com",
                "nibh. Quisque nonummy ipsum non arcu. Vivamus sit amet risus. Donec egestas. Aliquam nec enim. Nunc ut erat. Sed nunc est, mollis non, cursus non, egestas a, dui. Cras pellentesque. Sed dictum. Proin eget odio. Aliquam vulputate ullamcorper magna. Sed eu eros. Nam consequat dolor vitae dolor. Donec fringilla. Donec feugiat metus sit amet ante. Vivamus non lorem vitae odio sagittis semper. Nam tempor diam"
            ],
            [
                "Myles Chase",
                "-1.6442499964583",
                "mollis.non.cursus@tristiquesenectuset.ca",
                "molestie dapibus ligula. Aliquam erat volutpat. Nulla dignissim. Maecenas ornare egestas ligula. Nullam feugiat placerat velit. Quisque varius. Nam porttitor scelerisque neque. Nullam nisl. Maecenas malesuada fringilla est. Mauris eu turpis. Nulla aliquet. Proin velit. Sed malesuada augue ut lacus. Nulla tincidunt, neque vitae semper egestas, urna justo faucibus lectus, a sollicitudin orci sem eget massa. Suspendisse eleifend. Cras sed leo. Cras vehicula aliquet libero. Integer in magna. Phasellus dolor elit, pellentesque"
            ],
            [
                "Mark Fitzgerald",
                "3.3596166320255",
                "sollicitudin@Donecfeugiatmetus.com",
                "natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Proin vel nisl. Quisque fringilla euismod enim. Etiam gravida molestie arcu."
            ],
            [
                "Zachery Walsh",
                "3.5871951530794",
                "sit.amet.massa@telluseu.co.uk",
                "Sed et libero. Proin mi. Aliquam gravida mauris ut mi. Duis risus odio, auctor"
            ],
            [
                "Tyrone Hogan",
                "0.65198505567554",
                "felis.eget.varius@velvulputateeu.edu",
                "eu"
            ],
            [
                "Dante Gordon",
                "2.4654363408172",
                "sodales.Mauris.blandit@tellus.org",
                "vulputate dui, nec tempus mauris erat eget ipsum. Suspendisse sagittis. Nullam vitae diam. Proin dolor. Nulla semper tellus id nunc interdum feugiat. Sed nec metus facilisis lorem tristique aliquet. Phasellus fermentum convallis ligula. Donec luctus aliquet odio. Etiam ligula tortor, dictum eu, placerat eget, venenatis a, magna. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Etiam laoreet, libero et tristique pellentesque, tellus sem mollis dui, in sodales elit erat vitae risus. Duis a mi fringilla mi lacinia"
            ],
            [
                "Aladdin Foster",
                "2.9542768691297",
                "ut.erat@Phasellusataugue.net",
                "Vivamus sit amet risus. Donec egestas. Aliquam nec enim. Nunc ut erat. Sed nunc est, mollis non, cursus non, egestas a, dui. Cras pellentesque. Sed dictum. Proin eget odio. Aliquam vulputate ullamcorper magna. Sed eu eros. Nam consequat dolor vitae dolor. Donec fringilla. Donec feugiat metus sit amet ante. Vivamus non lorem vitae odio sagittis semper. Nam tempor diam dictum sapien. Aenean massa. Integer vitae nibh. Donec est mauris, rhoncus id, mollis nec, cursus a, enim. Suspendisse aliquet, sem"
            ],
            [
                "Silas Erickson",
                "0.17533130381752",
                "non.leo.Vivamus@ipsumnonarcu.edu",
                "magna. Praesent interdum ligula eu enim. Etiam imperdiet dictum magna. Ut tincidunt orci quis lectus. Nullam suscipit, est ac facilisis facilisis, magna tellus faucibus leo, in lobortis tellus justo sit amet nulla. Donec non justo. Proin non massa non ante bibendum ullamcorper. Duis cursus, diam at pretium aliquet, metus urna convallis erat, eget tincidunt dui augue eu tellus. Phasellus elit pede, malesuada vel, venenatis vel, faucibus id, libero. Donec consectetuer mauris"
            ],
            [
                "Avram Walls",
                "2.4721166900916",
                "orci.tincidunt@tortorat.com",
                "nunc id enim. Curabitur massa. Vestibulum accumsan neque et nunc. Quisque ornare tortor at risus. Nunc ac sem ut dolor dapibus gravida. Aliquam tincidunt, nunc ac mattis ornare, lectus ante dictum mi, ac mattis velit justo nec ante. Maecenas mi felis, adipiscing fringilla, porttitor vulputate, posuere vulputate, lacus. Cras interdum. Nunc sollicitudin"
            ],
            [
                "Porter Walter",
                "3.7058417984546",
                "placerat@quis.ca",
                "nulla. Donec non justo. Proin non massa non ante bibendum ullamcorper. Duis cursus, diam at pretium aliquet, metus urna convallis erat, eget tincidunt dui augue eu tellus. Phasellus elit pede, malesuada vel, venenatis vel, faucibus id, libero. Donec consectetuer mauris id sapien. Cras dolor dolor, tempus non, lacinia at, iaculis quis, pede. Praesent eu dui. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aenean eget magna. Suspendisse tristique neque venenatis"
            ],
            [
                "Honorato Glenn",
                "0.45774163592354",
                "Morbi.accumsan.laoreet@pharetraNamac.net",
                "Aliquam ornare, libero at auctor ullamcorper, nisl arcu iaculis enim, sit amet ornare lectus justo eu arcu. Morbi sit amet massa. Quisque porttitor eros nec tellus. Nunc"
            ],
            [
                "Castor Rocha",
                "5.3057451914525",
                "eros.turpis@sapienimperdiet.ca",
                "Nulla semper tellus id nunc interdum feugiat. Sed nec metus facilisis lorem tristique aliquet. Phasellus fermentum convallis ligula. Donec luctus aliquet odio. Etiam ligula tortor, dictum eu, placerat eget, venenatis a, magna. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Etiam laoreet, libero et"
            ],
            [
                "Wallace Cantrell",
                "1.5780227213515",
                "laoreet@Vestibulumanteipsum.edu",
                "mus. Donec dignissim magna a tortor. Nunc commodo auctor velit. Aliquam nisl. Nulla eu neque pellentesque massa lobortis ultrices. Vivamus rhoncus. Donec est. Nunc ullamcorper, velit in aliquet lobortis, nisi nibh lacinia orci, consectetuer euismod est arcu ac orci. Ut semper pretium neque. Morbi quis urna. Nunc quis arcu vel quam dignissim pharetra. Nam ac nulla. In tincidunt congue turpis. In condimentum. Donec at arcu. Vestibulum ante ipsum primis in faucibus"
            ],
            [
                "Alan Lyons",
                "-1.3592972807138",
                "lorem.sit@Donectempuslorem.net",
                "In mi pede, nonummy ut, molestie in, tempus eu, ligula. Aenean euismod mauris eu elit. Nulla facilisi. Sed neque. Sed eget lacus. Mauris non dui nec urna suscipit nonummy. Fusce fermentum fermentum arcu. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Phasellus ornare. Fusce mollis."
            ],
            [
                "Leroy Boyle",
                "4.6394981156692",
                "malesuada@diamlorem.org",
                "est."
            ],
            [
                "Micah Guzman",
                "2.8703558761468",
                "augue@elitNullafacilisi.ca",
                "Donec tempus, lorem fringilla ornare placerat, orci lacus vestibulum lorem, sit amet ultricies sem magna nec quam. Curabitur vel lectus. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec dignissim magna a tortor. Nunc commodo auctor velit. Aliquam nisl. Nulla eu neque pellentesque massa lobortis ultrices. Vivamus rhoncus. Donec est. Nunc ullamcorper, velit in aliquet lobortis, nisi nibh lacinia orci, consectetuer euismod est arcu ac orci. Ut semper pretium neque. Morbi"
            ],
            [
                "Callum Brooks",
                "-0.96170658390365",
                "eget.massa@inaliquet.edu",
                "a feugiat tellus lorem"
            ],
            [
                "Ryder Weber",
                "1.6768444090056",
                "odio.Phasellus.at@nonmassa.ca",
                "semper cursus. Integer mollis. Integer tincidunt aliquam arcu. Aliquam ultrices iaculis odio. Nam interdum enim non nisi. Aenean eget metus. In nec orci. Donec nibh. Quisque nonummy ipsum non arcu. Vivamus sit amet risus. Donec egestas. Aliquam nec enim. Nunc ut erat. Sed nunc est,"
            ],
            [
                "Ulric Briggs",
                "-0.65281544443019",
                "arcu@sagittis.org",
                "Suspendisse non leo. Vivamus nibh dolor, nonummy ac, feugiat non, lobortis quis, pede. Suspendisse dui. Fusce diam nunc, ullamcorper eu, euismod ac, fermentum vel, mauris. Integer sem elit, pharetra ut, pharetra sed, hendrerit a, arcu. Sed et libero. Proin mi. Aliquam gravida mauris ut mi. Duis risus"
            ],
            [
                "Zephania Wolfe",
                "-1.0663470152788",
                "interdum.Nunc@eget.co.uk",
                "a ultricies adipiscing, enim mi tempor lorem, eget mollis lectus pede et risus. Quisque libero lacus, varius et, euismod et, commodo at, libero. Morbi accumsan laoreet ipsum. Curabitur consequat, lectus sit amet luctus vulputate, nisi sem"
            ],
            [
                "Vernon Collins",
                "0.96171776003428",
                "arcu.Morbi.sit@quispede.edu",
                "vitae odio sagittis semper. Nam tempor diam dictum sapien. Aenean massa. Integer vitae nibh. Donec est mauris, rhoncus id, mollis nec, cursus a, enim. Suspendisse aliquet, sem ut cursus luctus, ipsum leo elementum sem, vitae aliquam eros turpis non enim. Mauris quis turpis vitae purus"
            ],
            [
                "Slade Potter",
                "6.944424067028",
                "feugiat.metus@risus.edu",
                "arcu. Aliquam ultrices iaculis odio. Nam interdum enim non nisi. Aenean eget metus. In nec orci. Donec nibh. Quisque nonummy ipsum non arcu. Vivamus sit amet risus. Donec egestas. Aliquam nec enim. Nunc ut erat. Sed nunc est, mollis non, cursus non,"
            ],
            [
                "Scott Osborne",
                "-0.8219277954245",
                "tempor.diam@consectetueradipiscing.org",
                "imperdiet, erat nonummy ultricies ornare, elit elit fermentum risus, at fringilla purus mauris a nunc. In at pede. Cras vulputate velit eu sem. Pellentesque ut ipsum ac mi eleifend egestas. Sed pharetra, felis eget varius ultrices, mauris ipsum porta elit, a feugiat tellus lorem eu metus. In lorem. Donec elementum, lorem ut aliquam iaculis, lacus"
            ],
            [
                "Dale Pena",
                "-2.6963522007683",
                "nulla.Integer@loremac.edu",
                "libero lacus, varius et, euismod et, commodo at, libero. Morbi accumsan laoreet ipsum. Curabitur consequat, lectus sit amet luctus vulputate, nisi sem semper erat, in consectetuer ipsum nunc id enim. Curabitur massa. Vestibulum accumsan neque et nunc. Quisque ornare tortor at risus. Nunc ac sem ut dolor dapibus gravida. Aliquam tincidunt, nunc ac mattis ornare, lectus ante dictum mi, ac mattis velit justo nec ante. Maecenas mi felis, adipiscing fringilla, porttitor vulputate, posuere vulputate, lacus. Cras interdum. Nunc sollicitudin commodo ipsum. Suspendisse non leo."
            ],
            [
                "Drew Acevedo",
                "0.22425876566644",
                "Etiam.ligula.tortor@magnaPraesent.edu",
                "iaculis nec, eleifend non, dapibus rutrum, justo. Praesent luctus. Curabitur egestas nunc sed libero. Proin sed turpis nec mauris blandit mattis. Cras eget nisi dictum augue malesuada malesuada. Integer id magna et ipsum cursus vestibulum. Mauris magna. Duis dignissim tempor arcu. Vestibulum ut eros non enim commodo hendrerit. Donec porttitor tellus non magna."
            ],
            [
                "Joseph Holloway",
                "3.2484894944076",
                "cubilia.Curae.Donec@arcuMorbisit.co.uk",
                "tempor erat neque non quam. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aliquam fringilla cursus purus. Nullam scelerisque neque sed sem egestas blandit. Nam nulla magna, malesuada vel, convallis in, cursus et, eros. Proin ultrices. Duis volutpat nunc sit amet metus. Aliquam erat volutpat. Nulla facilisis. Suspendisse"
            ],
            [
                "Hashim Hunt",
                "3.7611250844844",
                "gravida.Praesent.eu@euodiotristique.co.uk",
                "hendrerit neque. In ornare sagittis felis. Donec tempor, est ac mattis semper, dui lectus rutrum urna, nec luctus felis purus ac tellus. Suspendisse sed dolor. Fusce mi lorem, vehicula et, rutrum eu, ultrices sit amet, risus. Donec nibh enim, gravida sit amet, dapibus id, blandit at, nisi. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Proin vel nisl. Quisque fringilla euismod enim. Etiam gravida molestie arcu. Sed eu nibh vulputate mauris sagittis placerat. Cras dictum ultricies ligula. Nullam enim. Sed nulla ante, iaculis nec, eleifend non, dapibus rutrum, justo. Praesent luctus. Curabitur egestas nunc sed libero."
            ],
            [
                "Elton Marsh",
                "1.1611870562918",
                "dolor.dolor@Aliquamgravida.org",
                "nibh lacinia orci, consectetuer euismod est arcu ac orci. Ut semper pretium neque. Morbi quis urna. Nunc quis arcu vel quam dignissim pharetra. Nam ac nulla. In tincidunt congue turpis. In condimentum. Donec at arcu. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices"
            ],
            [
                "Demetrius Browning",
                "0.80158215866453",
                "nibh@iaculisnec.org",
                "et, eros. Proin ultrices. Duis volutpat nunc sit amet metus. Aliquam erat volutpat. Nulla facilisis. Suspendisse commodo tincidunt nibh. Phasellus nulla. Integer vulputate, risus a ultricies adipiscing, enim mi tempor lorem, eget mollis lectus pede et risus. Quisque libero lacus, varius et, euismod et, commodo at, libero. Morbi accumsan laoreet ipsum. Curabitur consequat, lectus sit amet luctus vulputate, nisi sem semper erat, in consectetuer ipsum nunc id enim. Curabitur massa. Vestibulum accumsan neque et nunc. Quisque ornare tortor at risus. Nunc"
            ],
            [
                "Bevis Mcfarland",
                "0.30128351197158",
                "Nam@dui.org",
                "Etiam laoreet, libero et tristique pellentesque, tellus sem mollis dui, in sodales elit erat vitae risus. Duis a mi fringilla mi lacinia mattis. Integer eu lacus. Quisque imperdiet, erat nonummy ultricies ornare, elit elit fermentum risus, at fringilla purus mauris a nunc. In at pede. Cras vulputate velit eu sem. Pellentesque ut ipsum ac mi eleifend egestas. Sed pharetra, felis eget varius ultrices, mauris ipsum porta elit, a feugiat tellus lorem eu metus. In lorem. Donec elementum, lorem"
            ],
            [
                "Branden Berry",
                "2.4066575933311",
                "ultricies.ornare@interdum.edu",
                "venenatis a, magna. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Etiam laoreet, libero et tristique pellentesque, tellus sem mollis dui, in sodales"
            ],
            [
                "Josiah Quinn",
                "-2.4753853101846",
                "nunc.risus.varius@imperdietullamcorper.edu",
                "blandit congue. In scelerisque scelerisque dui. Suspendisse ac metus vitae velit egestas lacinia. Sed congue, elit sed consequat auctor, nunc nulla vulputate dui, nec tempus mauris erat eget ipsum. Suspendisse sagittis. Nullam vitae diam. Proin dolor."
            ],
            [
                "Jerome Clark",
                "-0.68994637737092",
                "nec.cursus@condimentumeget.org",
                "gravida sit amet, dapibus id, blandit at, nisi. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Proin vel nisl. Quisque fringilla euismod enim. Etiam gravida molestie arcu. Sed eu nibh vulputate mauris sagittis placerat. Cras dictum ultricies ligula. Nullam enim. Sed nulla ante, iaculis nec, eleifend non, dapibus rutrum, justo. Praesent luctus. Curabitur egestas nunc sed libero. Proin sed turpis nec mauris blandit mattis. Cras eget nisi dictum augue malesuada malesuada. Integer id magna et ipsum cursus vestibulum. Mauris magna. Duis dignissim tempor arcu."
            ],
            [
                "Hall Delaney",
                "4.982605394196",
                "aliquet.molestie@massa.net",
                "auctor odio a purus. Duis elementum, dui quis accumsan convallis, ante lectus convallis est, vitae sodales nisi magna sed dui. Fusce aliquam, enim nec tempus scelerisque, lorem ipsum sodales purus, in molestie tortor nibh sit amet orci. Ut sagittis lobortis mauris. Suspendisse aliquet molestie tellus. Aenean egestas hendrerit neque. In ornare sagittis felis. Donec tempor, est ac mattis semper, dui lectus rutrum urna, nec luctus felis purus ac tellus. Suspendisse sed dolor. Fusce"
            ],
            [
                "Ishmael Jacobs",
                "-1.4192648005693",
                "consectetuer.adipiscing.elit@liberoInteger.org",
                "Donec at arcu. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Donec tincidunt. Donec vitae erat vel pede blandit congue. In scelerisque scelerisque dui. Suspendisse ac metus vitae velit egestas lacinia. Sed congue, elit sed consequat auctor, nunc nulla vulputate dui, nec tempus mauris erat eget ipsum. Suspendisse sagittis. Nullam vitae diam. Proin dolor. Nulla semper tellus id nunc interdum feugiat. Sed nec metus facilisis lorem tristique aliquet. Phasellus fermentum convallis ligula. Donec luctus aliquet odio. Etiam ligula tortor, dictum eu, placerat eget, venenatis a, magna."
            ],
            [
                "Jordan Roth",
                "-1.5429754167248",
                "non.cursus@Etiambibendumfermentum.org",
                "faucibus. Morbi vehicula. Pellentesque tincidunt tempus risus. Donec egestas. Duis ac arcu. Nunc mauris. Morbi non sapien molestie orci tincidunt adipiscing. Mauris molestie pharetra"
            ],
            [
                "Brady Collins",
                "-0.17245973265889",
                "tellus.imperdiet.non@dapibusrutrum.org",
                "Sed auctor odio a purus. Duis elementum, dui quis accumsan convallis, ante lectus convallis est, vitae sodales nisi magna sed dui. Fusce aliquam, enim nec tempus scelerisque, lorem ipsum sodales purus, in molestie tortor nibh sit amet orci. Ut sagittis lobortis mauris. Suspendisse aliquet molestie tellus. Aenean egestas hendrerit neque."
            ],
            [
                "Myles Olsen",
                "1.7861207328842",
                "vitae.aliquet@tellus.ca",
                "enim. Etiam gravida molestie arcu. Sed eu nibh vulputate mauris sagittis placerat. Cras dictum ultricies ligula. Nullam enim. Sed nulla ante, iaculis nec, eleifend non, dapibus rutrum, justo. Praesent luctus. Curabitur egestas nunc sed libero. Proin sed turpis nec mauris blandit mattis. Cras eget nisi dictum augue malesuada malesuada. Integer id magna et ipsum"
            ],
            [
                "Ivan Knowles",
                "4.1453146849747",
                "sem.molestie.sodales@Vestibulum.ca",
                "lacus. Nulla tincidunt, neque vitae semper egestas, urna justo faucibus lectus, a sollicitudin orci sem eget massa. Suspendisse eleifend. Cras sed leo. Cras vehicula aliquet libero. Integer in magna. Phasellus dolor elit, pellentesque a, facilisis non, bibendum sed, est. Nunc laoreet lectus quis massa. Mauris vestibulum, neque sed dictum eleifend, nunc risus varius orci, in consequat enim diam vel arcu. Curabitur ut odio vel est tempor bibendum. Donec felis orci, adipiscing non, luctus sit amet, faucibus ut, nulla. Cras eu tellus eu augue porttitor interdum. Sed auctor odio a purus. Duis elementum, dui"
            ],
            [
                "Cain Watts",
                "-0.030489647464192",
                "fames.ac@bibendumDonec.net",
                "et, magna. Praesent interdum ligula eu enim. Etiam"
            ],
            [
                "Beau Gibson",
                "-1.837832743224",
                "Ut.tincidunt@tortornibh.com",
                "arcu iaculis enim, sit amet ornare lectus justo eu arcu. Morbi sit amet massa. Quisque porttitor eros nec tellus. Nunc lectus pede, ultrices a, auctor non, feugiat nec, diam. Duis mi enim, condimentum eget, volutpat ornare, facilisis eget, ipsum. Donec sollicitudin adipiscing ligula. Aenean gravida nunc sed pede. Cum sociis natoque penatibus"
            ],
            [
                "Melvin Cannon",
                "-3.3119731013116",
                "adipiscing.lobortis@ametrisus.net",
                "metus. In nec orci. Donec nibh. Quisque nonummy ipsum non arcu. Vivamus sit amet risus. Donec egestas. Aliquam nec enim."
            ],
            [
                "Fritz Bean",
                "-2.5906932148993",
                "semper@vitaedolorDonec.co.uk",
                "tincidunt pede ac urna. Ut tincidunt vehicula risus. Nulla eget metus eu erat semper rutrum."
            ],
            [
                "Anthony Hawkins",
                "-0.67372668563255",
                "erat.nonummy@tortor.ca",
                "convallis erat, eget tincidunt dui augue eu tellus. Phasellus elit pede, malesuada vel, venenatis vel, faucibus id, libero. Donec consectetuer mauris id sapien. Cras dolor dolor, tempus non, lacinia at, iaculis quis, pede. Praesent eu dui. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aenean eget magna. Suspendisse tristique neque venenatis lacus. Etiam bibendum fermentum metus. Aenean sed pede nec ante blandit viverra. Donec tempus,"
            ],
            [
                "Quamar Norton",
                "-1.4736499148849",
                "lectus@volutpatNulladignissim.co.uk",
                "Maecenas iaculis aliquet diam. Sed diam"
            ],
            [
                "Abdul Decker",
                "-3.843727324784",
                "nec.mollis@etrisus.org",
                "arcu. Vestibulum ut eros non enim commodo hendrerit. Donec porttitor tellus non magna. Nam ligula elit, pretium et, rutrum non, hendrerit id, ante. Nunc mauris sapien, cursus in, hendrerit consectetuer, cursus et, magna. Praesent interdum ligula eu enim. Etiam imperdiet dictum magna. Ut tincidunt orci quis lectus. Nullam suscipit, est ac facilisis facilisis, magna tellus faucibus leo, in lobortis tellus justo sit amet nulla. Donec"
            ],
            [
                "Xavier Harper",
                "-0.36097301764123",
                "sodales.nisi.magna@pedeSuspendissedui.edu",
                "Integer urna. Vivamus"
            ],
            [
                "Tanner Estrada",
                "0.48270337988774",
                "accumsan@sempercursus.net",
                "tempor erat neque non quam. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aliquam fringilla cursus purus. Nullam scelerisque neque sed sem egestas blandit. Nam nulla magna, malesuada vel, convallis in, cursus et, eros. Proin"
            ],
            [
                "Timothy Sharp",
                "0.58137910463222",
                "gravida.Praesent.eu@euplacerateget.com",
                "dis parturient montes, nascetur ridiculus mus. Proin vel arcu eu odio tristique pharetra. Quisque ac libero nec ligula"
            ],
            [
                "Kieran Clayton",
                "0.98005356053939",
                "ut@idnuncinterdum.co.uk",
                "elit erat vitae risus. Duis a mi fringilla mi lacinia mattis. Integer eu lacus. Quisque imperdiet, erat nonummy ultricies ornare, elit elit fermentum risus, at fringilla purus mauris a nunc. In at pede. Cras vulputate velit eu sem. Pellentesque ut ipsum ac mi eleifend egestas. Sed pharetra, felis eget varius ultrices, mauris ipsum porta elit, a feugiat tellus lorem eu metus. In lorem. Donec elementum, lorem ut aliquam iaculis, lacus pede sagittis augue, eu tempor erat neque non quam. Pellentesque habitant morbi tristique senectus et netus et"
            ],
            [
                "Erasmus Huffman",
                "1.8806709370891",
                "vulputate.risus.a@ac.edu",
                "dolor dolor, tempus non, lacinia at, iaculis quis, pede. Praesent eu dui. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aenean eget magna. Suspendisse tristique neque venenatis lacus. Etiam bibendum fermentum metus. Aenean sed pede nec ante blandit viverra. Donec tempus, lorem fringilla ornare placerat, orci lacus vestibulum lorem, sit amet ultricies sem magna nec quam. Curabitur vel lectus. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec dignissim magna a tortor. Nunc commodo auctor velit. Aliquam nisl. Nulla eu"
            ],
            [
                "Forrest Russell",
                "8.5332255400929",
                "velit@accumsansedfacilisis.org",
                "tempor bibendum. Donec felis orci, adipiscing non, luctus sit amet,"
            ],
            [
                "Dennis Sykes",
                "-1.8076412489931",
                "accumsan.interdum@senectus.com",
                "sit amet lorem semper auctor. Mauris vel turpis. Aliquam adipiscing lobortis risus. In mi pede, nonummy ut, molestie in, tempus eu, ligula. Aenean euismod mauris eu elit. Nulla facilisi. Sed neque. Sed eget lacus. Mauris non dui nec urna suscipit nonummy. Fusce fermentum fermentum arcu. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Phasellus ornare. Fusce mollis. Duis sit amet diam eu dolor egestas rhoncus. Proin nisl sem, consequat nec, mollis vitae, posuere at,"
            ],
            [
                "Timothy Lowe",
                "-2.0903915164183",
                "amet@ante.net",
                "malesuada malesuada. Integer id magna et ipsum cursus vestibulum. Mauris magna. Duis dignissim tempor arcu. Vestibulum ut eros non enim commodo hendrerit. Donec porttitor tellus non magna. Nam ligula elit, pretium et, rutrum non, hendrerit id, ante. Nunc mauris sapien, cursus in, hendrerit consectetuer, cursus et, magna. Praesent interdum ligula eu enim. Etiam imperdiet dictum magna."
            ],
            [
                "Quentin Mack",
                "-1.4391826485347",
                "hendrerit@portaelit.ca",
                "consectetuer, cursus et, magna. Praesent interdum ligula eu enim. Etiam imperdiet dictum magna. Ut tincidunt orci quis lectus. Nullam suscipit, est ac facilisis facilisis, magna tellus faucibus leo, in lobortis tellus justo sit"
            ],
            [
                "Joseph Greer",
                "-0.48789210895226",
                "pretium@nullamagnamalesuada.com",
                "metus eu erat semper rutrum. Fusce dolor quam, elementum at, egestas a, scelerisque sed, sapien. Nunc pulvinar arcu et pede. Nunc sed orci lobortis augue scelerisque mollis. Phasellus libero mauris, aliquam eu, accumsan sed, facilisis vitae, orci. Phasellus dapibus quam quis diam. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Fusce aliquet magna a neque. Nullam ut nisi a odio semper cursus. Integer mollis. Integer tincidunt aliquam arcu. Aliquam ultrices iaculis odio. Nam interdum enim non nisi. Aenean eget metus. In nec orci."
            ],
            [
                "Lane Yates",
                "-0.56844090764023",
                "libero.Proin.mi@Donec.co.uk",
                "sem elit, pharetra ut, pharetra sed, hendrerit a, arcu. Sed et libero. Proin mi. Aliquam gravida mauris ut mi. Duis risus odio, auctor vitae, aliquet nec, imperdiet nec, leo. Morbi neque tellus, imperdiet non, vestibulum nec, euismod in, dolor. Fusce feugiat. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aliquam auctor, velit eget laoreet posuere,"
            ],
            [
                "Fritz Mccall",
                "-0.55275693523155",
                "ligula.Nullam.feugiat@eleifendvitae.co.uk",
                "a, scelerisque sed, sapien. Nunc pulvinar arcu et pede. Nunc sed orci lobortis augue scelerisque mollis. Phasellus libero mauris, aliquam eu, accumsan sed, facilisis vitae, orci. Phasellus dapibus quam quis diam. Pellentesque habitant morbi tristique senectus et netus et malesuada"
            ],
            [
                "Amir Tyler",
                "2.4082553783746",
                "sollicitudin@bibendumfermentummetus.net",
                "eu elit. Nulla facilisi. Sed neque. Sed eget lacus. Mauris non dui nec urna suscipit nonummy. Fusce fermentum fermentum arcu. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Phasellus ornare. Fusce mollis. Duis sit amet diam eu dolor egestas rhoncus. Proin nisl sem, consequat nec, mollis vitae, posuere at, velit. Cras lorem lorem, luctus ut, pellentesque eget, dictum placerat, augue. Sed molestie. Sed"
            ],
            [
                "Chadwick Dixon",
                "1.9932249513776",
                "ac.fermentum.vel@Donec.co.uk",
                "est. Nunc laoreet lectus quis massa. Mauris vestibulum, neque sed dictum eleifend, nunc risus varius orci, in consequat enim diam vel arcu. Curabitur ut odio vel est tempor bibendum. Donec felis orci, adipiscing non, luctus sit amet, faucibus ut, nulla. Cras eu tellus eu augue porttitor interdum. Sed auctor odio a purus. Duis elementum, dui quis accumsan convallis, ante lectus convallis est, vitae sodales nisi magna sed dui. Fusce aliquam, enim nec tempus scelerisque, lorem"
            ],
            [
                "Marvin Brady",
                "0.05781232512703",
                "ligula@purusaccumsan.org",
                "Phasellus dapibus quam quis diam. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Fusce aliquet magna a neque. Nullam ut nisi a odio semper cursus. Integer mollis. Integer tincidunt aliquam arcu. Aliquam ultrices iaculis odio. Nam interdum enim non nisi. Aenean eget metus. In nec orci. Donec nibh. Quisque nonummy ipsum non arcu. Vivamus sit amet risus. Donec egestas. Aliquam nec enim. Nunc ut erat. Sed nunc est, mollis non, cursus non, egestas a, dui. Cras pellentesque. Sed dictum. Proin eget odio. Aliquam vulputate ullamcorper magna. Sed eu eros."
            ],
            [
                "Vaughan Battle",
                "1.5361009969472",
                "vel.turpis.Aliquam@sagittisaugueeu.co.uk",
                "arcu. Morbi sit amet massa. Quisque porttitor eros nec tellus. Nunc lectus pede, ultrices a, auctor non, feugiat nec, diam. Duis mi enim, condimentum eget, volutpat ornare, facilisis eget, ipsum. Donec sollicitudin adipiscing ligula. Aenean gravida nunc sed pede. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Proin vel arcu eu odio tristique pharetra. Quisque ac libero nec ligula consectetuer rhoncus. Nullam velit dui,"
            ],
            [
                "Mufutau Hensley",
                "-3.1209431406531",
                "libero.nec@Maurisnon.net",
                "egestas. Aliquam nec enim. Nunc ut erat. Sed nunc est, mollis non, cursus non, egestas a, dui. Cras pellentesque. Sed dictum. Proin"
            ],
            [
                "Hashim Burgess",
                "-1.0366913548628",
                "amet@pedesagittis.co.uk",
                "Aliquam adipiscing lobortis risus. In mi"
            ],
            [
                "Keegan Dickson",
                "-0.29610893334066",
                "ligula.consectetuer.rhoncus@Quisquetincidunt.com",
                "Quisque ornare tortor at risus. Nunc ac sem ut dolor dapibus gravida. Aliquam tincidunt, nunc ac mattis ornare, lectus ante dictum mi, ac mattis velit justo nec ante. Maecenas mi felis, adipiscing fringilla, porttitor vulputate, posuere vulputate, lacus. Cras interdum. Nunc sollicitudin commodo ipsum. Suspendisse non leo. Vivamus nibh dolor, nonummy ac, feugiat non, lobortis quis, pede. Suspendisse dui. Fusce diam nunc, ullamcorper eu, euismod ac, fermentum vel, mauris. Integer sem elit, pharetra ut, pharetra sed, hendrerit"
            ],
            [
                "Emmanuel Cochran",
                "-3.8255590426156",
                "pellentesque@Mauris.net",
                "Cras lorem lorem, luctus ut, pellentesque eget, dictum placerat, augue. Sed molestie. Sed id risus quis diam luctus lobortis."
            ],
            [
                "Coby Munoz",
                "0.21262067727363",
                "vulputate@Donec.edu",
                "ullamcorper magna. Sed eu eros. Nam consequat dolor vitae dolor. Donec fringilla. Donec feugiat metus sit amet ante. Vivamus non lorem vitae odio sagittis semper. Nam tempor diam"
            ],
            [
                "Hamish Wilkerson",
                "-0.89291892461309",
                "felis.Donec@malesuada.edu",
                "ornare egestas ligula. Nullam feugiat placerat velit. Quisque varius. Nam porttitor scelerisque neque. Nullam nisl. Maecenas malesuada fringilla est. Mauris eu turpis. Nulla aliquet. Proin velit. Sed malesuada augue ut lacus. Nulla tincidunt, neque vitae semper egestas, urna justo faucibus lectus, a sollicitudin orci sem eget"
            ],
            [
                "Channing West",
                "1.974470855538",
                "vulputate.dui.nec@lacus.co.uk",
                "ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Phasellus ornare. Fusce mollis. Duis sit amet diam eu dolor egestas rhoncus. Proin nisl sem, consequat nec, mollis vitae, posuere at, velit. Cras lorem lorem, luctus ut, pellentesque eget, dictum placerat, augue. Sed molestie. Sed id risus quis diam luctus lobortis. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Mauris ut"
            ]
        ]
    }`;

    private enum testString2 = `[
      {
        "id": 0,
        "guid": "9f9b6edf-2386-4681-bdac-1797f5e5e397",
        "isActive": true,
        "balance": "$1,381.05",
        "picture": "http://placehold.it/32x32",
        "age": 21,
        "eyeColor": "brown",
        "name": "Dodson Lamb",
        "gender": "male",
        "company": "ZENTILITY",
        "email": "dodsonlamb@zentility.com",
        "phone": "+1 (878) 551-3097",
        "address": "328 Campus Place, Sparkill, New Jersey, 3647",
        "about": "In nostrud nostrud reprehenderit anim duis labore. Officia ut sit sunt Lorem. In ipsum aute sit mollit mollit non. Duis sit est eu aliqua amet. Exercitation esse nostrud cillum aute ad excepteur esse est nostrud.\r\n",
        "registered": "2014-04-02T11:36:36 +07:00",
        "latitude": 23.677115,
        "longitude": -148.126595,
        "tags": [
          "tempor",
          "excepteur",
          "dolor",
          "eu",
          "adipisicing",
          "dolor",
          "Lorem"
        ],
        "friends": [
          {
            "id": 0,
            "name": "Harrell Sheppard"
          },
          {
            "id": 1,
            "name": "Alana Hardin"
          },
          {
            "id": 2,
            "name": "Hollie Merritt"
          }
        ],
        "greeting": "Hello, Dodson Lamb! You have 6 unread messages.",
        "favoriteFruit": "strawberry"
      },
      {
        "id": 1,
        "guid": "d25a9f69-a260-458f-bcac-0e1e59e05215",
        "isActive": true,
        "balance": "$3,733.60",
        "picture": "http://placehold.it/32x32",
        "age": 29,
        "eyeColor": "blue",
        "name": "Nell Ray",
        "gender": "female",
        "company": "FUTURITY",
        "email": "nellray@futurity.com",
        "phone": "+1 (823) 450-2959",
        "address": "761 Tompkins Avenue, Kansas, Marshall Islands, 8019",
        "about": "Incididunt anim in minim sint laborum consectetur sint adipisicing. Aliqua ullamco eiusmod aute quis voluptate reprehenderit pariatur ea eu sunt. Consectetur commodo Lorem laborum dolore eiusmod nisi dolor laborum. Magna mollit Lorem occaecat aliqua est consectetur officia quis cillum ea ea laborum. Aliqua et enim cillum dolor ad labore cillum quis non officia est pariatur incididunt mollit. Dolor elit aliquip ullamco esse magna commodo in.\r\n",
        "registered": "2014-01-30T21:32:18 +08:00",
        "latitude": 51.832448,
        "longitude": -98.48817,
        "tags": [
          "eu",
          "qui",
          "ad",
          "consequat",
          "occaecat",
          "ullamco",
          "est"
        ],
        "friends": [
          {
            "id": 0,
            "name": "Letha Ramsey"
          },
          {
            "id": 1,
            "name": "Lewis Cotton"
          },
          {
            "id": 2,
            "name": "Vega Hunt"
          }
        ],
        "greeting": "Hello, Nell Ray! You have 4 unread messages.",
        "favoriteFruit": "banana"
      },
      {
        "id": 2,
        "guid": "95deefa7-5468-4838-bbbc-c17e5d8afca7",
        "isActive": false,
        "balance": "$2,920.86",
        "picture": "http://placehold.it/32x32",
        "age": 36,
        "eyeColor": "green",
        "name": "Parks Wyatt",
        "gender": "male",
        "company": "NETPLODE",
        "email": "parkswyatt@netplode.com",
        "phone": "+1 (857) 514-3706",
        "address": "220 Canda Avenue, Wilsonia, Texas, 8807",
        "about": "Magna mollit incididunt ex occaecat mollit. Et dolore amet duis enim aute est dolor tempor sunt velit. Nisi anim reprehenderit eiusmod nostrud ut ut ea labore sint enim ut ut. Nisi laborum incididunt velit est irure nisi. Velit ut commodo ullamco magna ullamco fugiat cupidatat consequat enim. Aliqua reprehenderit ipsum quis sit duis consectetur nulla proident eu velit ex.\r\n",
        "registered": "2014-02-12T23:53:10 +08:00",
        "latitude": -57.207168,
        "longitude": 157.559663,
        "tags": [
          "pariatur",
          "laborum",
          "cillum",
          "aute",
          "excepteur",
          "deserunt",
          "cupidatat"
        ],
        "friends": [
          {
            "id": 0,
            "name": "Hart Gillespie"
          },
          {
            "id": 1,
            "name": "Donaldson Wise"
          },
          {
            "id": 2,
            "name": "Heidi Horton"
          }
        ],
        "greeting": "Hello, Parks Wyatt! You have 2 unread messages.",
        "favoriteFruit": "strawberry"
      },
      {
        "id": 3,
        "guid": "b675df80-e3fc-4cd5-819d-dbb2e2285734",
        "isActive": true,
        "balance": "$1,475.81",
        "picture": "http://placehold.it/32x32",
        "age": 26,
        "eyeColor": "blue",
        "name": "Amber Petty",
        "gender": "female",
        "company": "NSPIRE",
        "email": "amberpetty@nspire.com",
        "phone": "+1 (950) 443-2267",
        "address": "601 Amersfort Place, Bath, Arizona, 7539",
        "about": "In proident duis dolore voluptate est velit aute non tempor est nisi non nisi occaecat. Tempor consequat exercitation minim eiusmod sunt cillum ex voluptate aute pariatur magna consectetur esse. Eiusmod culpa ex est do consectetur mollit. Eu proident quis culpa aliquip aute do pariatur consequat sit id irure consectetur irure. Tempor nulla reprehenderit qui cupidatat excepteur sit eiusmod exercitation duis laborum laboris. Laboris laboris minim fugiat nostrud minim qui sit Lorem. Cillum aliqua magna sit velit eiusmod magna.\r\n",
        "registered": "2014-07-14T00:12:43 +07:00",
        "latitude": -41.714895,
        "longitude": 177.329422,
        "tags": [
          "duis",
          "voluptate",
          "veniam",
          "id",
          "dolore",
          "dolore",
          "voluptate"
        ],
        "friends": [
          {
            "id": 0,
            "name": "Hernandez Stephens"
          },
          {
            "id": 1,
            "name": "Strickland Harper"
          },
          {
            "id": 2,
            "name": "Pope Knowles"
          }
        ],
        "greeting": "Hello, Amber Petty! You have 6 unread messages.",
        "favoriteFruit": "strawberry"
      },
      {
        "id": 4,
        "guid": "22051a85-3d83-43ed-9219-f3df28b4f67a",
        "isActive": true,
        "balance": "$3,291.25",
        "picture": "http://placehold.it/32x32",
        "age": 24,
        "eyeColor": "brown",
        "name": "Pennington Burt",
        "gender": "male",
        "company": "INSECTUS",
        "email": "penningtonburt@insectus.com",
        "phone": "+1 (875) 423-2987",
        "address": "881 Powers Street, Williamson, Indiana, 7457",
        "about": "Cillum consectetur ea do laborum mollit officia nulla nisi ut laborum consequat voluptate dolore mollit. Ea consequat esse deserunt dolor aliquip eiusmod irure commodo nisi. Voluptate esse dolor et commodo do elit enim cillum magna.\r\n",
        "registered": "2014-01-30T15:34:15 +08:00",
        "latitude": -46.545254,
        "longitude": -67.199307,
        "tags": [
          "excepteur",
          "id",
          "tempor",
          "veniam",
          "velit",
          "occaecat",
          "velit"
        ],
        "friends": [
          {
            "id": 0,
            "name": "Giles Underwood"
          },
          {
            "id": 1,
            "name": "Bernard Short"
          },
          {
            "id": 2,
            "name": "Josefina Weiss"
          }
        ],
        "greeting": "Hello, Pennington Burt! You have 6 unread messages.",
        "favoriteFruit": "apple"
      },
      {
        "id": 5,
        "guid": "feec8dbd-4f61-4adf-8f45-1b2d5f0b5e65",
        "isActive": false,
        "balance": "$3,919.03",
        "picture": "http://placehold.it/32x32",
        "age": 31,
        "eyeColor": "green",
        "name": "Esther Herring",
        "gender": "female",
        "company": "XYLAR",
        "email": "estherherring@xylar.com",
        "phone": "+1 (973) 436-3800",
        "address": "926 Baycliff Terrace, Biehle, Georgia, 3487",
        "about": "Sint Lorem excepteur fugiat est quis consequat ea. Cillum incididunt enim exercitation tempor quis excepteur laboris minim. Eiusmod ullamco minim commodo deserunt.\r\n",
        "registered": "2014-03-20T19:18:54 +07:00",
        "latitude": 89.573316,
        "longitude": 40.609971,
        "tags": [
          "reprehenderit",
          "sint",
          "veniam",
          "non",
          "dolor",
          "commodo",
          "incididunt"
        ],
        "friends": [
          {
            "id": 0,
            "name": "Traci Newman"
          },
          {
            "id": 1,
            "name": "Hull Charles"
          },
          {
            "id": 2,
            "name": "Christian Nielsen"
          }
        ],
        "greeting": "Hello, Esther Herring! You have 6 unread messages.",
        "favoriteFruit": "apple"
      }
    ]`;
}

unittest {
    import std.algorithm;
    import std.math;

    static void test(string txt)
    {
        auto val = toJSONValue(txt);
        // Note: order is undefined due to AA use in JSONValue
        //assert(val.toJSONString() == val.toJSONString().parseJSON().toJSONString());

        static bool ncmp(JSONParserNode a, JSONParserNode b)
        {
            if (a.kind == b.kind && a.kind == JSONParserNode.Kind.literal) {
                if (a.literal.kind == b.literal.kind && a.literal.kind == JSONToken.Kind.number)
                    return a.literal.number.approxEqual(b.literal.number);
            }
            return a == b;
        }

        auto nodes = parseJSONStream(txt);
        auto nodes2 = nodes.toJSONString().parseJSONStream();
        assert(equal!ncmp(nodes, nodes2));
    }

    test(testString1);
    test(testString2);
}
