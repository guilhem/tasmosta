import webserver # import webserver class
import string
import persist
import json
import MatrixController
import fonts

instagram_logo = [
    [ {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': false} ],
    [ {'enable': true, 'color': 0xE1306C}, {'enable': false, 'color': 0x000000}, {'enable': false}, {'enable': false}, {'enable': false}, {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C} ],
    [ {'enable': true, 'color': 0xE1306C}, {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C} ],
    [ {'enable': true, 'color': 0xE1306C}, {'enable': false}, {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': false}, {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C} ],
    [ {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': false}, {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C} ],
    [ {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': false}, {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C} ],
    [ {'enable': true, 'color': 0xE1306C}, {'enable': false}, {'enable': false}, {'enable': false}, {'enable': false}, {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C} ],
    [ {'enable': false}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': true, 'color': 0xE1306C}, {'enable': false} ]
]

class Tasmosta : Driver

  var matrixController

  var brightness
  var color
  var colorIdx

  def init()

    print("ClockfaceManager Init");
    self.matrixController = MatrixController();

    self.brightness = 50;
    self.color = fonts.palette['white']
    self.colorIdx = 0;

    self.matrixController.print_string("Hello :)", 3, 2, true, self.color, self.brightness)
    self.matrixController.draw()

    tasmota.add_cmd("Tasmosta", /  c, i, p, j -> self.set_followers_count( c, i, p, j))
    tasmota.add_cron("*/15 * * * * *", / -> self.get_followers(), "get_followers")
    self.web_add_handler()
  end

  # Add HTTP POST and GET handlers for configuration
  def web_add_handler()
    webserver.on('/hm', / -> self.http_get(), webserver.HTTP_GET)
    webserver.on('/hm', / -> self.http_post(), webserver.HTTP_POST)
  end

  # Displays a "Configure Heating" button on the configuration page
  def web_add_config_button()
    var button = "<form action='/hm' method='get'><button>Configure Instagram Counter</button></form>"
    webserver.content_send(button)
  end

  # Display information on the main page
  def web_sensor()
    # display access key
    tasmota.web_send(persist.find('tasmosta_access_key', "no key"))
  end

  def http_get()
    if !webserver.check_privileged_access() return nil end
    webserver.content_start('Configure Instagram Counter')
    webserver.content_send_style()

    # Set instagram access key input form
    webserver.content_send("<form action='/hm' method='post'>")
    webserver.content_send("<label for='access_key'>Access Key:</label>")
    webserver.content_send(string.format("<input type='text' id='access_key' name='access_key' value='%s')", persist.find('tasmosta_access_key', 'no key')))
    webserver.content_send("<button name='o' class='button bgrn' type='submit'>Save</button>")
    webserver.content_send("</form>")

    webserver.content_button(webserver.BUTTON_CONFIGURATION)
    webserver.content_stop()
  end

  def http_post()
    if !webserver.check_privileged_access() return nil end
    if webserver.has_arg('access_key')
      self.save_access_key(webserver.arg('access_key'))
    else
      log("No access key provided")
    end

    self.http_get()
  end

  def save_access_key(key)
    log(string.format("Saving access key: %s", key))
    persist.setmember('tasmosta_access_key', key)
    persist.save()
  end

  def get_followers()
    if !persist.has('tasmosta_access_key')
      log("No access key provided")
      return nil
    end

    var cl = webclient()
    cl.begin(string.format("https://graph.instagram.com/v20.0/me?fields=followers_count&access_token=%s", persist.find('tasmosta_access_key')))

    var r = cl.GET()

    if r != 200
      log("Failed to get followers count")
      return nil
    end

    var s = cl.get_string()
    var resp = json.load(s)

    log(string.format("cron: Followers count: %d", resp['followers_count']))
    tasmota.cmd(string.format("Tasmosta %d", resp['followers_count']))

    # tasmota.set_timer(30000,get_followers)
  end

  def set_followers_count(cmd, idx, payload, payload_json)
    self.print_followers(payload)

    tasmota.resp_cmnd_done()
  end

  def print_followers(nb_followers)

    var logo_width = size(instagram_logo)

    self.matrixController.clear()
    self.print_bitmap(instagram_logo, 0, 0)

    var strfollowers = ''
    for i: 0..(5 - size(nb_followers))
      strfollowers += ' '
    end

    strfollowers += nb_followers

    self.matrixController.print_string(strfollowers, logo_width + 1, 2, false, self.color, self.brightness)
    self.matrixController.draw()
  end

  def print_bitmap(bitmap, start_x, start_y)
    var row_size = size(bitmap[0])  # Hauteur du bitmap (nombre de lignes)
    var col_size = size(bitmap)  # Largeur du bitmap (nombre de colonnes)

    # Parcourir chaque colonne et chaque pixel du bitmap
    for x:0..col_size-1
      for y:0..row_size-1
        var pixel = bitmap[x][y]
        if pixel['enable']
          # Convertir la couleur de chaîne hexadécimale à entier
          var color = pixel['color']
          self.matrixController.set_matrix_pixel_color(start_x + x, start_y + y, color, self.brightness)
        end
      end
    end
  end
end

return Tasmosta
