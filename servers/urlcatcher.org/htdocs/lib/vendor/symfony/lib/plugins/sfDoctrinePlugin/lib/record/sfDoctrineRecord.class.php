<?php

/*
 * This file is part of the symfony package.
 * (c) Fabien Potencier <fabien.potencier@symfony-project.com>
 * (c) Jonathan H. Wage <jonwage@gmail.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

/**
 * Base sfDoctrineRecord extends the base Doctrine_Record in Doctrine to provide some
 * symfony specific functionality to Doctrine_Records
 *
 * @package    symfony
 * @subpackage doctrine
 * @author     Fabien Potencier <fabien.potencier@symfony-project.com>
 * @author     Jonathan H. Wage <jonwage@gmail.com>
 * @version    SVN: $Id: sfDoctrineRecord.class.php 19997 2009-07-07 22:41:04Z Jonathan.Wage $
 */
abstract class sfDoctrineRecord extends Doctrine_Record
{
  static protected
    $_initialized    = false,
    $_defaultCulture = 'en';

  /**
   * Custom Doctrine_Record constructor.
   * Used to initialize I18n to make sure the culture is set from symfony
   *
   * @return void
   */
  public function construct()
  {
    self::initializeI18n();

    if ($this->getTable()->hasRelation('Translation'))
    {
      $this->unshiftFilter(new sfDoctrineRecordI18nFilter());
    }
  }

  /**
   * Initialize I18n culture from symfony sfUser instance
   * Add event listener to change default culture whenever the user changes culture
   *
   * @return void
   */
  public static function initializeI18n()
  {
    if (!self::$_initialized)
    {
      if (!self::$_initialized && class_exists('sfProjectConfiguration', false))
      {
        $dispatcher = sfProjectConfiguration::getActive()->getEventDispatcher();
        $dispatcher->connect('user.change_culture', array('sfDoctrineRecord', 'listenToChangeCultureEvent'));
      }

      if (class_exists('sfContext', false) && sfContext::hasInstance() && $user = sfContext::getInstance()->getUser())
      {
        self::$_defaultCulture = $user->getCulture();
      }
      self::$_initialized = true;
    }
  }

  /**
   * Listens to the user.change_culture event.
   *
   * @param sfEvent An sfEvent instance
   */
  public static function listenToChangeCultureEvent(sfEvent $event)
  {
    self::$_defaultCulture = $event['culture'];
  }

  /**
   * Sets the default culture
   *
   * @param string $culture
   */
  static public function setDefaultCulture($culture)
  {
    self::$_defaultCulture = $culture;
  }

  /**
   * Return the default culture
   *
   * @return string the default culture
   */
  static public function getDefaultCulture()
  {
    self::initializeI18n();

    if (!self::$_defaultCulture)
    {
      throw new sfException('The default culture has not been set');
    }
    return self::$_defaultCulture;
  }

  /**
   * Get the primary key of a Doctrine_Record.
   * This a proxy method to Doctrine_Record::identifier() for Propel BC
   *
   * @return mixed $identifier Array for composite primary keys and string for single primary key
   */
  public function getPrimaryKey()
  {
    $identifier = (array) $this->identifier();
    return end($identifier);
  }

  /**
   * Function require by symfony >= 1.2 admin generators
   *
   * @return boolean
   */
  public function isNew()
  {
    return ! $this->exists();
  }

  /**
   * Returns a string representation of the record.
   *
   * @return string A string representation of the record.
   */
  public function __toString()
  {
    $guesses = array('name',
                     'title',
                     'description',
                     'subject',
                     'keywords',
                     'id');

    // we try to guess a column which would give a good description of the object
    foreach ($guesses as $descriptionColumn)
    {
      try
      {
        return (string) $this->get($descriptionColumn);
      } catch (Exception $e) {}
    }

    return sprintf('No description for object of class "%s"', $this->getTable()->getComponentName());
  }

  /*
   * Provide accessors with setters and getters to Doctrine models.
   *
   * @param  string $method     The method name.
   * @param  array  $arguments  The method arguments.
   * @return mixed The returned value of the called method.
   */
  public function __call($method, $arguments)
  {
    try {
      if (in_array($verb = substr($method, 0, 3), array('set', 'get')))
      {
        $name = substr($method, 3);

        $table = $this->getTable();
        if ($table->hasRelation($name))
        {
          $entityName = $name;
        }
        else if ($table->hasField($fieldName = $table->getFieldName($name)))
        {
          $entityNameLower = strtolower($fieldName);
          if ($table->hasField($entityNameLower))
          {
            $entityName = $entityNameLower;
          } else {
            $entityName = $fieldName;
          }
        }
        else
        {
          $underScored = $table->getFieldName(sfInflector::underscore($name));
          if ($table->hasField($underScored) || $table->hasRelation($underScored))
          {
            $entityName = $underScored;
          } else if ($table->hasField(strtolower($name)) || $table->hasRelation(strtolower($name))) {
            $entityName = strtolower($name);
          } else {
            $camelCase = $table->getFieldName(sfInflector::camelize($name));
            $camelCase = strtolower($camelCase[0]).substr($camelCase, 1, strlen($camelCase));
            if ($table->hasField($camelCase) || $table->hasRelation($camelCase))
            {
              $entityName = $camelCase;
            } else {
              $entityName = $underScored;
            }
          }
        }

        return call_user_func_array(
          array($this, $verb),
          array_merge(array($entityName), $arguments)
        );
      } else {
        return parent::__call($method, $arguments);
      }
    } catch(Exception $e) {
      return parent::__call($method, $arguments);
    }
  }

  /**
   * Get the Doctrine date value as a PHP DateTime object
   *
   * @param string $dateFieldName   The field name to get the DateTime object for
   * @return DateTime $dateTime     The instance of PHPs DateTime
   */
  public function getDateTimeObject($dateFieldName)
  {
    $type = $this->getTable()->getTypeOf($dateFieldName);
    if ($type == 'date' || $type == 'timestamp')
    {
      return new DateTime($this->get($dateFieldName));
    }
    else
    {
      throw new sfException('Cannot call getDateTimeObject() on a field that is not of type date or timestamp.');
    }
  }

  /**
   * Set the Doctrine date value by passing a valid PHP DateTime object instance
   *
   * @param string $dateFieldName       The field name to set the date for
   * @param DateTime $dateTimeObject    The DateTime instance to use to set the value
   * @return void
   */
  public function setDateTimeObject($dateFieldName, DateTime $dateTimeObject)
  {
    $type = $this->getTable()->getTypeOf($dateFieldName);
    if ($type == 'date' || $type == 'timestamp')
    {
      return $this->set($dateFieldName, $dateTimeObject->format('Y-m-d H:i:s'));
    }
    else
    {
      throw new sfException('Cannot call setDateTimeObject() on a field that is not of type date or timestamp.');
    }
  }
}